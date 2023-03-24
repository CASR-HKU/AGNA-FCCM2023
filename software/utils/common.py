import logging
from functools import reduce


agna_dim_tuple = ('K', 'C', 'I', 'J', 'H', 'W')
"""(0, 1, 2, 3, 4, 5)

(K, C, I, J, H, W)
"""

agna_level_tuple = ('T', 'S', 'P', 'Q', 'F')
"""(0, 1, 2, 3, 4)

(T, S, P, Q, F)
"""

def list_prod(var):
    return reduce(lambda x,y:x*y, var)

def list_sum(var):
    return reduce(lambda x,y:x+y, var)

def short_str(s:str, l:int=30) -> str:
    """Return shortened string to given length.
    s: input string
    l: length
    """
    tmp_s = s if isinstance(s, str) else str(s)
    out_s = tmp_s if len(tmp_s)<l else tmp_s[:l//2]+'..'+tmp_s[-(l - l//2 - 2):]
    return out_s

def init_root_logger() -> logging.Logger:
    """Initialize root logger.
    """
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)
    for hdlr in logger.handlers:
        logger.removeHandler(hdlr)
    logger.addHandler(get_streamhdlr())
    logger.propagate = False
    return logger

def get_logfmt() -> logging.Formatter:
    """Get log formatter.
    """
    log_fmt = logging.Formatter(
        '[%(asctime)s]-%(levelname)s-%(name)s %(message)s',
        '%H:%M:%S')
    return log_fmt

def get_streamhdlr() -> logging.StreamHandler:
    """Get stream handler.
    """
    sh = logging.StreamHandler()
    sh.setLevel(logging.INFO)
    sh.setFormatter(get_logfmt())
    return sh

def get_filehdlr(path:str, debug=True) -> logging.FileHandler:
    """Get file handler.
    path: file path
    """
    fh = logging.FileHandler(path, 'w')
    if debug:
        fh.setLevel(logging.DEBUG)
    else:
        fh.setLevel(logging.INFO)
    fh.setFormatter(get_logfmt())
    return fh

def add_filehdlr(path:str, debug=True) -> logging.FileHandler:
    """Add file handler to root logger.
    logger_name: logger name
    path: file path
    """
    logger = logging.getLogger()
    fh = get_filehdlr(path, debug)
    logger.addHandler(fh)
    return fh

def rm_filehdlr(fh:logging.FileHandler) -> None:
    """Remove file handler from root logger.
    fh: file handler
    """
    logger = logging.getLogger()
    logger.removeHandler(fh)
