import csv
import logging
import os

from solver.arch_search import ArchSearch
from solver.op_schedule import OperationSchedule
from utils.arch_spec import ArchSpec
from utils.common import add_filehdlr, rm_filehdlr
from utils.model_spec import ModelSpec
from utils.node_param import NodeParam
from utils.hw_sim import HardwareSimulator
from utils.platform_spec import PlatformSpec
from utils.schedule_param import ScheduleParam


class AGNA:

    def __init__(
            self,
            pltfm_spec:PlatformSpec,
            model_spec_list:list[ModelSpec],
            output_dir:str) -> None:
        self._logger = logging.getLogger(self.__class__.__name__)
        self._pltfm_spec = pltfm_spec
        self._model_spec_list = model_spec_list
        self._output_dir = output_dir
        self.logger.info(f"Platform: {self.pltfm_spec.name}")
        self.logger.info(f"Models: {[ms.name for ms in self.model_spec_list]}")
        self.logger.info(f"Output dir: {self.output_dir}")

    def run_arch(self) -> None:
        """Run AGNA.
        """
        # solve arch_search
        path_prefix = os.path.join(self.output_dir, 'arch_search')
        arch_spec = ArchSpec.load(path_prefix+'.json')
        if arch_spec:
            self.logger.info(
                'Found exsiting arch_search from '
                + path_prefix + '.json')
            self.pltfm_spec.summary()
            arch_spec.summary()
            self.logger.info(f"dsp_uti: {arch_spec.total_dsp_num/self.pltfm_spec.max_dsp}")
            if arch_spec.total_dsp_num>self.pltfm_spec.max_dsp:
                self.logger.error(
                    f"Total DSP number {arch_spec.total_dsp_num} "
                    + f"exceeds max DSP number {self.pltfm_spec.max_dsp}.")
            self.logger.info(f"bram_uti: {arch_spec.total_bram_num/self.pltfm_spec.max_bram}")
            if arch_spec.total_bram_num>self.pltfm_spec.max_bram:
                self.logger.error(
                    f"Total BRAM number {arch_spec.total_bram_num} "
                    + f"exceeds max BRAM number {self.pltfm_spec.max_bram}.")
        else:
            arch_spec = self.run_arch_search(path_prefix)
            if arch_spec is None:
                return
        self.update_csv()

    def run(self) -> None:
        """Run AGNA.
        """
        # solve arch_search
        path_prefix = os.path.join(self.output_dir, 'arch_search')
        arch_spec = ArchSpec.load(path_prefix+'.json')
        if arch_spec:
            self.logger.info(
                'Found exsiting arch_search from '
                + path_prefix + '.json')
        else:
            arch_spec = self.run_arch_search(path_prefix)
            if arch_spec is None:
                return
        # solve op_schedule
        for node in self.model_spec_list[0].unique_nodes:
            # only schedule for unique node
            path_prefix = os.path.join(
                self.output_dir, f"op_schedule_{node.name}")
            # load its current schedule
            schd_param = ScheduleParam.load(path_prefix+'.json')
            # if current schedule exists
            if schd_param:
                self.logger.info('Found exsiting op_schedule')
                node.set_schedule(schd_param)
                continue
            # if current schedule does not exist
            else:
                schd_param = self.run_op_schedule(
                    arch_spec, node, path_prefix)
                node.set_schedule(schd_param)

    def update_json(self) -> None:
        """Update json.
        """
        self.logger.info("Start update_json.")
        arch_spec = ArchSpec.load( os.path.join(
            self.output_dir, 'arch_search.json'))
        if arch_spec is None:
            self.logger.error("No arch spec found.")
            return
        # load all schedule
        model_spec = self.model_spec_list[0]
        json_path = os.path.join(
            self.output_dir,
            'agna-'+self.pltfm_spec.name+'-'+model_spec.name+'.json')
        for node in model_spec.nodes:
            if node.same_as is None:
                schd_param = ScheduleParam.load(os.path.join(
                    self.output_dir, f"op_schedule_{node.name}.json"))
            else:
                src_node = model_spec.get_node(node.same_as)
                schd_param = ScheduleParam.load(os.path.join(
                    self.output_dir, f"op_schedule_{src_node.name}.json"))
            # if current schedule exists
            if schd_param is None:
                self.logger.error(f"No schedule found for {node.name}.")
                return
            node.set_schedule(schd_param)
        model_spec.pe_num = arch_spec.pe_num
        model_spec.save(json_path)
        # self.logger.info(f"Saved json to {json_path}.")

    def update_csv(self) -> None:
        """Update csv.
        """
        self.logger.info("Start update_csv.")
        arch_spec = ArchSpec.load(os.path.join(
            self.output_dir, 'arch_search.json'))
        for model_spec in self.model_spec_list:
            csv_path = os.path.join(
                self.output_dir,
                'agna-'+self.pltfm_spec.name+'-'+model_spec.name+'.csv')
            with open(csv_path, 'w') as f:
                csv_writer = csv.writer(f)
                csv_header = list(NodeParam.get_csv_header())
                csv_header[0] = model_spec.name
                csv_writer.writerow(csv_header)
                idx_unique_cnt = csv_header.index('unique_cnt')
                idx_same_as = csv_header.index('same_as')
                idx_schedule = csv_header.index('schedule')
                idx_theo_cycle = csv_header.index('theo_cycle')
                idx_schd_cycle = csv_header.index('schd_cycle')
                theo_cycle = 0
                schd_cycle = 0
                no_schedule_nodes = []
                for node_param in model_spec.nodes:
                    schd_param = ScheduleParam.load(os.path.join(
                            self.output_dir,
                            'op_schedule_'+node_param.name+'.json'))
                    node_param.set_schedule(schd_param)
                    csv_row = node_param.get_csv_row(arch_spec)
                    csv_writer.writerow(csv_row)
                    theo_cycle += csv_row[idx_unique_cnt]*csv_row[idx_theo_cycle]
                    if csv_row[idx_same_as] is None:
                        if csv_row[idx_schedule] is None:
                            no_schedule_nodes.append(node_param.name)
                        else:
                            schd_cycle += csv_row[idx_unique_cnt]*csv_row[idx_schd_cycle]
                csv_last_row = [theo_cycle, schd_cycle, schd_cycle/theo_cycle]
                csv_writer.writerow(csv_last_row)
                csv_last_row = [theo_cycle/200e3, schd_cycle/200e3]
                csv_writer.writerow(csv_last_row)
                csv_writer.writerow(no_schedule_nodes)
            self.logger.info(f"Saved csv to {csv_path}.")

    def run_arch_search(self, path_prefix: str) -> ArchSpec:
        # log
        self.logger.info("Start arch_search.")
        # add filehdlr
        fh = add_filehdlr(path_prefix+'.log')
        # create and run arch_search
        arch_search_config = {
            'pack_dsp': self.pltfm_spec.data_width==8,
            'max_of_2': False,
            # 'use_close': False,
            # 'consider_s': True,
            # 'bound_range': 2,
            # 'add_bound': True,
            'timelimits': 300,
        }
        arch_search = ArchSearch(
            self.pltfm_spec,
            self.model_spec_list,
            path_prefix,
            arch_search_config)
        arch_search.optimize()
        # check if best arch spec found
        if arch_search.best_solution is None:
            self.logger.error("No arch spec found.")
        else:
            self.logger.info("Best arch spec found.")
            arch_search.best_solution.summary()
            arch_search.best_solution.save(path_prefix+'.json')
        # remove filehdlr
        rm_filehdlr(fh)
        return arch_search.best_solution

    def run_op_schedule(
            self,
            arch_spec:ArchSpec,
            node_param:NodeParam,
            path_prefix:str) -> ScheduleParam:
        # log
        self.logger.info("Start op_schedule.")
        # add filehdlr
        fh = add_filehdlr(path_prefix + '.log')
        # create and run op_schedule
        op_schedule_config = {
            # 'bound_range': 4,
            'force_full_w': True,
            'timelimits': 300,
            'max_of_2': False,
        }
        op_schedule = OperationSchedule(
            arch_spec,
            node_param,
            path_prefix,
            op_schedule_config)
        op_schedule.optimize()
        # check if best schedule found
        if op_schedule.best_solution:
            self.logger.info("Best schedule found.")
            op_schedule.best_solution.summary()
            op_schedule.best_solution.save(path_prefix+'.json')
        else:
            self.logger.info("Second try.")
            op_schedule_config['bound_range'] = 2*op_schedule.config['bound_range']
            op_schedule = OperationSchedule(
                arch_spec,
                node_param,
                path_prefix,
                op_schedule_config)
            op_schedule.optimize()
            if op_schedule.best_solution:
                self.logger.info("Best schedule found.")
                op_schedule.best_solution.summary()
                op_schedule.best_solution.save(path_prefix+'.json')
            else:
                self.logger.error("No best schedule found.")
        # remove filehdlr
        rm_filehdlr(fh)
        return op_schedule.best_solution

    def simulate(self) -> None:
        # add filehdlr
        fh = add_filehdlr(os.path.join(self.output_dir, 'agna-sim.log'))
        arch_spec = ArchSpec.load(os.path.join(self.output_dir, 'arch_search.json'))
        if arch_spec is None:
            self.logger.error("No arch spec found.")
            return
        for node in self.model_spec_list[0].unique_nodes:
            if not node.same_as:
                schd_param = ScheduleParam.load(os.path.join(
                    self.output_dir, f"op_schedule_{node.name}.json"))
                # if current schedule exists
                if schd_param is None:
                    self.logger.error(f"No schedule found for {node.name}.")
                    return
                node.set_schedule(schd_param)
        hwsim = HardwareSimulator(arch_spec, self.model_spec_list[0])
        updt_events, exec_events, wrbk_events = hwsim.simulate()
        # hwsim.draw(updt_events, exec_events, wrbk_events, os.path.join(self.output_dir, 'sim.svg'))
        # hwsim.plot(updt_events, exec_events, wrbk_events, os.path.join(self.output_dir, 'sim.png'))
        # remove filehdlr
        rm_filehdlr(fh)

    @property
    def logger(self) -> logging.Logger:
        """Get logger.
        """
        return self._logger

    @property
    def pltfm_spec(self) -> PlatformSpec:
        """Platform spec.
        """
        return self._pltfm_spec

    @property
    def model_spec_list(self) -> list[ModelSpec]:
        """A list of ModelSpec.
        """
        return self._model_spec_list

    @property
    def output_dir(self) -> str:
        """Output directory.
        """
        return self._output_dir
