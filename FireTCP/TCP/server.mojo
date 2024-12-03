from ..connection import Connection
from .service import Service
from .request import Request
from .response import Response
from ..modules import PyModules
from ..server_stats import ServerStats
from ..server import Server
from FireTCP.common_messages import EMPTY_REQUEST_MESSAGE

from python import Python, PythonObject
import time


struct TCPLite[S: Service](Server):
    """'Lite' wrapper for the python socket library with HTTP protocol."""

    var __modules: PyModules
    var __py_socket: PythonObject
    var host_name: PythonObject
    var host_addr: StringLiteral
    var service: S
    var port: Int
    var stats: ServerStats

    fn __init__(
        inout self, service: S, port: Int, host_addr: StringLiteral
    ) raises -> None:
        self.port = port
        self.host_addr = host_addr
        self.service = service
        self.stats = ServerStats()
        self.__modules = PyModules()
        self.host_name = self.__modules.socket.gethostbyname(
            self.__modules.socket.gethostname(),
        )
        self.__py_socket = None
        self.__spinup_socket()
        self.__bind_pySocket()

    fn __bind_pySocket(self) raises -> None:
        """Private funciton that binds the initialized python socket to the given host and port. this runs in __init__()
        """
        _ = self.__py_socket.bind((self.host_addr, self.port))

    fn __close_socket(self) raises -> None:
        _ = self.__py_socket.close()

    fn __spinup_socket(inout self) raises -> None:
        self.__py_socket = self.__modules.socket.socket(
            self.__modules.socket.AF_INET,
            self.__modules.socket.SOCK_STREAM,
        )

    @always_inline
    fn __print_start(self) raises -> None:
        var fire = "🔥🔥🔥"
        print(fire + " FireApi TCPLite Service " + fire + "\n")
        print("listening @ " + self.full_addr() + " ...\n")

    @always_inline
    fn __accept_connection(self) raises -> Connection:
        var conn_addr = self.__py_socket.accept()
        return Connection(conn_addr=conn_addr, py=self.__modules.py)

    @always_inline
    fn full_addr(self) raises -> String:
        return str(self.host_addr) + "/" + str(self.port)

    @always_inline
    fn __update_metrics(inout self, et: Float64) -> None:
        """Private function that updates the metrics that enhance logging output.
        """
        self.stats.update(execution_time=et)

    fn serve(inout self) raises -> None:
        self.__print_start()

        while True:
            try:
                _ = self.__py_socket.listen()
                var connection: Connection = self.__accept_connection()
                connection.print_log_connect_message()

                var st: Float64 = time.now()
                var raw_request = connection.recieve_data()
                var response: Response = self.__handle_request(
                    raw_request=raw_request
                )

                connection.send_response[Response](response)
                connection.close()

                # update stats
                var execution_time: Float64 = (time.now() - st)
                self.__update_metrics(et=execution_time)
                response.print_log_message(
                    execution_time=self.stats.most_recent_secs(),
                    raw_request=raw_request,
                    symbol="🔥" if (
                        execution_time <= self.stats.average_execution_time
                    ) else "🥶",
                )
            except Error:  # keyboard interrupt
                self.__close_socket()
                break

    fn __handle_request(self, raw_request: String) raises -> Response:
        """Private function that makes generates a Response object given a Request object.
        """
        if not raw_request:
            return Response.empty_error(error_str=EMPTY_REQUEST_MESSAGE)

        try:
            var request = Request(body=raw_request)
            var response: Response = self.service.func(req=request)
            return response
        except Error:
            return Response.error(error_str=str(Error))
