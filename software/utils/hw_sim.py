from matplotlib import pyplot as plt
import logging
from utils.arch_spec import ArchSpec
from utils.common import list_sum
from utils.model_spec import ModelSpec


class HardwareSimulator:
    def __init__(self, arch_spec: ArchSpec, model_spec: ModelSpec) -> None:
        self._logger = logging.getLogger(self.__class__.__name__)
        self._arch_spec = arch_spec
        self._model_spec = model_spec

    def plot(self, updt_events, exec_events, wrbk_events, path):
        fig, ax = plt.subplots(figsize=(30, 3))
        for updt_event in updt_events:
            if updt_event["node_idx"] < 0:
                continue
            if updt_event["node_idx"] >= 2:
                break
            ax.barh(
                2,
                updt_event["cycle"],
                left=updt_event["beg_cycle"],
                color=f"C{updt_event['node_idx']}",
                edgecolor="black",
            )
        for exec_event in exec_events:
            if exec_event["node_idx"] < 0:
                continue
            if exec_event["node_idx"] >= 2:
                break
            ax.barh(
                1,
                exec_event["cycle"],
                left=exec_event["beg_cycle"],
                color=f"C{exec_event['node_idx']}",
                edgecolor="black",
            )
        for wrbk_event in wrbk_events:
            if wrbk_event["node_idx"] < 0:
                continue
            if wrbk_event["node_idx"] >= 2:
                break
            ax.barh(
                0,
                wrbk_event["cycle"],
                left=wrbk_event["beg_cycle"],
                color=f"C{wrbk_event['node_idx']}",
                edgecolor="black",
            )
        ax.set_yticks([0, 1, 2], labels=["write", "comp", "read"])
        plt.savefig(path)
        self.logger.info(f"Saved plot to {path}")

    def simulate(self) -> list:
        self.logger.info("Simulating...")
        updt_events = []
        exec_events = []
        wrbk_events = []
        nxt_updt_gen = self.next_updt_generator()
        updt = UPDT()
        nxt_exec_gen = self.next_exec_generator()
        exec = EXEC()
        nxt_wrbk_gen = self.next_wrbk_generator()
        wrbk = WRBK()
        curr_cycle = 0
        updt_des_rdy = [True, True]  # up, down
        exec_src_rdy = [False, False]  # up, down
        exec_des_rdy = [True, True]  # up, down
        wrbk_src_rdy = [False, False]  # up, down
        updt_des_sel = 0  # sel des of updt
        exec_src_sel = 0  # sel src of exec
        exec_des_sel = 0  # sel des of exec
        wrbk_src_sel = 0  # sel src of wrbk
        node_stall_en = True
        node_stall = False
        event_cnt = 0
        self.logger.info(f"node_stall_en: {node_stall_en}")
        while True:
            self.logger.debug(f"@{curr_cycle} ========== event_cnt = {event_cnt}")
            # find end of tile
            if updt.valid and curr_cycle == updt.end_cycle:
                exec_src_rdy[updt_des_sel] = True
                updt_des_sel = 1 - updt_des_sel
                self.logger.debug(f"updt end.")
                updt_events.append(
                    {
                        "beg_cycle": updt.beg_cycle,
                        "cycle": updt.cycle,
                        "end_cycle": updt.end_cycle,
                        "node_idx": updt.node_idx,
                        "tile_idx": updt.tile_idx,
                    }
                )
                if updt.last_of_node and node_stall_en:
                    node_stall = True
                    self.logger.debug(f"node stall.")
                updt = UPDT()
            if exec.valid and curr_cycle == exec.end_cycle:
                updt_des_rdy[exec_src_sel] = True
                exec_src_sel = 1 - exec_src_sel
                exec_events.append(
                    {
                        "beg_cycle": exec.beg_cycle,
                        "cycle": exec.cycle,
                        "end_cycle": exec.end_cycle,
                        "node_idx": exec.node_idx,
                        "tile_idx": exec.tile_idx,
                    }
                )
                if exec.wrbk_en:
                    wrbk_src_rdy[exec_des_sel] = True
                    exec_des_sel = 1 - exec_des_sel
                self.logger.debug(f"exec end.")
                exec = EXEC()
            if wrbk.valid and curr_cycle == wrbk.end_cycle:
                exec_des_rdy[wrbk_src_sel] = True
                wrbk_src_sel = 1 - wrbk_src_sel
                self.logger.debug(f"wrbk end.")
                wrbk_events.append(
                    {
                        "beg_cycle": wrbk.beg_cycle,
                        "cycle": wrbk.cycle,
                        "end_cycle": wrbk.end_cycle,
                        "node_idx": wrbk.node_idx,
                        "tile_idx": wrbk.tile_idx,
                    }
                )
                if wrbk.last_of_node and node_stall_en:
                    node_stall = False
                    self.logger.debug(f"node unstall.")
                wrbk = WRBK()
            for row in range(2):
                self.logger.debug(
                    ("updt_des->" if updt_des_sel == row else "          ")
                    + f"{str(updt_des_rdy[row]):<5}"
                    + "  "
                    + f"{str(exec_src_rdy[row]):>5}"
                    + ("<-exec_src" if exec_src_sel == row else "          ")
                    + "  "
                    + ("exec_des->" if exec_des_sel == row else "          ")
                    + f"{str(exec_des_rdy[row]):<5}"
                    + "  "
                    + f"{str(wrbk_src_rdy[row]):>5}"
                    + ("<-wrbk_src" if wrbk_src_sel == row else "          ")
                )
            # find beg of tile
            if not updt.valid and updt_des_rdy[updt_des_sel] and not node_stall:
                updt = next(nxt_updt_gen, UPDT())
                updt.beg_cycle = curr_cycle
                if updt.valid:
                    updt_des_rdy[updt_des_sel] = False
                    self.logger.debug(f"updt beg: {updt}")
            if (
                not exec.valid
                and exec_src_rdy[exec_src_sel]
                and exec_des_rdy[exec_des_sel]
            ):
                exec = next(nxt_exec_gen, EXEC())
                exec.beg_cycle = curr_cycle
                if exec.valid:
                    exec_src_rdy[exec_src_sel] = False
                    exec_des_rdy[exec_des_sel] = not exec.wrbk_en
                    self.logger.debug(f"exec beg: {exec}")
            if not wrbk.valid and wrbk_src_rdy[wrbk_src_sel]:
                wrbk = next(nxt_wrbk_gen, WRBK())
                wrbk.beg_cycle = curr_cycle
                if wrbk.valid:
                    wrbk_src_rdy[wrbk_src_sel] = False
                    self.logger.debug(f"wrbk beg: {wrbk}")
            next_cycle = min(updt.end_cycle, exec.end_cycle, wrbk.end_cycle)
            if next_cycle == float("inf"):
                self.logger.debug([updt.end_cycle, exec.end_cycle, wrbk.end_cycle])
                break
            curr_cycle = next_cycle
            event_cnt += 1
        self.logger.info(f"Simulation done @{curr_cycle}. {event_cnt} events.")
        return updt_events, exec_events, wrbk_events

    def next_updt_generator(self):
        for node_idx, node in enumerate(self.model_spec.nodes):
            if node.same_as:
                node.set_schedule(self.model_spec.get_node(node.same_as).schedule)
            node_perf = node.eval_perf(self.arch_spec)
            for tk in range(node.schedule.T[0]):
                for th in range(node.schedule.T[4]):
                    for tw in range(node.schedule.T[5]):
                        for tc in range(node.schedule.T[1]):
                            last_node = node is self.model_spec.nodes[-1]
                            first_of_node = tk == 0 and th == 0 and tw == 0 and tc == 0
                            last_of_node = (
                                tk == node.schedule.T[0] - 1
                                and th == node.schedule.T[4] - 1
                                and tw == node.schedule.T[5] - 1
                                and tc == node.schedule.T[1] - 1
                            )
                            last_of_model = last_node and last_of_node
                            yield UPDT(
                                {
                                    "node_idx": node_idx,
                                    "tile_idx": (tk, tc, th, tw),
                                    "cycle": node_perf["abuf_cycle"]
                                    + node_perf["wbuf_cycle"],
                                    # 'cycle': max(node_perf['abuf_cycle'],node_perf['wbuf_cycle']),
                                    "first_of_node": first_of_node,
                                    "last_of_node": last_of_node,
                                    "last_of_model": last_of_model,
                                }
                            )

    def next_exec_generator(self):
        for node_idx, node in enumerate(self.model_spec.nodes):
            if node.same_as:
                node.set_schedule(self.model_spec.get_node(node.same_as).schedule)
            node_perf = node.eval_perf(self.arch_spec)
            for tk in range(node.schedule.T[0]):
                for th in range(node.schedule.T[4]):
                    for tw in range(node.schedule.T[5]):
                        for tc in range(node.schedule.T[1]):
                            if node.is_dpws:
                                wrbk_en = True
                            else:
                                wrbk_en = tc == node.schedule.T[1] - 1
                            last_node = node is self.model_spec.nodes[-1]
                            first_of_node = tk == 0 and th == 0 and tw == 0 and tc == 0
                            last_of_node = (
                                tk == node.schedule.T[0] - 1
                                and th == node.schedule.T[4] - 1
                                and tw == node.schedule.T[5] - 1
                                and tc == node.schedule.T[1] - 1
                            )
                            last_of_model = last_node and last_of_node
                            yield EXEC(
                                {
                                    "node_idx": node_idx,
                                    "tile_idx": (tk, tc, th, tw),
                                    "cycle": node_perf["pe_cycle"],
                                    "wrbk_en": wrbk_en,
                                    "first_of_node": first_of_node,
                                    "last_of_node": last_of_node,
                                    "last_of_model": last_of_model,
                                }
                            )

    def next_wrbk_generator(self):
        for node_idx, node in enumerate(self.model_spec.nodes):
            if node.same_as:
                node.set_schedule(self.model_spec.get_node(node.same_as).schedule)
            node_perf = node.eval_perf(self.arch_spec)
            ch_idx = 1 if node.is_dpws else 0
            for tk in range(node.schedule.T[ch_idx]):
                for th in range(node.schedule.T[4]):
                    for tw in range(node.schedule.T[5]):
                        last_node = node is self.model_spec.nodes[-1]
                        first_of_node = tk == 0 and th == 0 and tw == 0
                        last_of_node = (
                            tk == node.schedule.T[ch_idx] - 1
                            and th == node.schedule.T[4] - 1
                            and tw == node.schedule.T[5] - 1
                        )
                        last_of_model = last_node and last_of_node
                        yield WRBK(
                            {
                                "node_idx": node_idx,
                                "tile_idx": (tk, 0, th, tw),
                                "cycle": node_perf["pbuf_cycle"],
                                "first_of_node": first_of_node,
                                "last_of_node": last_of_node,
                                "last_of_model": last_of_model,
                            }
                        )

    @property
    def logger(self) -> logging.Logger:
        """Get logger."""
        return self._logger

    @property
    def arch_spec(self) -> ArchSpec:
        return self._arch_spec

    @property
    def model_spec(self) -> ModelSpec:
        return self._model_spec


class TILE:
    def __init__(self, params=None):
        if params is None:
            self.valid = False
        else:
            for k in self.param_keys:
                setattr(self, "_" + k, params[k])
            self.valid = True

    def __repr__(self) -> str:
        return list_sum([f"{k}={getattr(self, k)} " for k in self.param_keys])

    @property
    def param_keys(self):
        return [
            "node_idx",
            "tile_idx",
            "cycle",
            "first_of_node",
            "last_of_node",
            "last_of_model",
        ]

    @property
    def node_idx(self) -> tuple:
        return self._node_idx if self.valid else -1

    @property
    def tile_idx(self) -> tuple:
        return self._tile_idx if self.valid else (-1, -1, -1, -1)

    @property
    def beg_cycle(self) -> int:
        return self._beg_cycle if self.valid else float("inf")

    @beg_cycle.setter
    def beg_cycle(self, value: int):
        if self.valid:
            self._beg_cycle = value

    @property
    def cycle(self) -> int:
        return self._cycle if self.valid else float("inf")

    @property
    def end_cycle(self) -> int:
        return self.beg_cycle + self.cycle if self.valid else float("inf")

    @property
    def first_of_node(self) -> bool:
        return self._first_of_node if self.valid else False

    @property
    def last_of_node(self) -> bool:
        return self._last_of_node if self.valid else False

    @property
    def last_of_model(self) -> bool:
        return self._last_of_model if self.valid else False


class UPDT(TILE):
    pass


class EXEC(TILE):
    @property
    def param_keys(self):
        return super().param_keys + ["wrbk_en"]

    @property
    def wrbk_en(self) -> bool:
        return self._wrbk_en if self.valid else False


class WRBK(TILE):
    pass
