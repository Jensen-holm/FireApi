from python import Python, PythonObject
from FireApi.connection import Connection
from FireApi.route import Route
from FireApi.request import Request
from FireApi.response import Response
from FireApi.modules import PyModules


struct Server:
    var _modules: PyModules
    var _py_socket: PythonObject
    var _host_name: PythonObject
    var _host_addr: StringLiteral
    var _port: Int

    fn __init__(
        inout self: Self, host_addr: StringLiteral = "", port: Int = 8080
    ) raises -> None:
        self._port = port
        self._host_addr = host_addr
        self._modules = PyModules()

        self._host_name = self._modules.socket.gethostbyname(
            self._modules.socket.gethostname(),
        )
        self._py_socket = self._modules.socket.socket(
            self._modules.socket.AF_INET,
            self._modules.socket.SOCK_STREAM,
        )

    fn __bind_pySocket(borrowed self) raises -> None:
        try:
            _ = self._py_socket.bind((self._host_addr, self._port))
        except Exception:
            raise Error("error binding pysocket to hostAddr & port")

    fn __close_socket(borrowed self) raises -> None:
        _ = self._py_socket.close()

    fn __print_running[T: Route](borrowed self, route: T) -> None:
        let endpoint = "http://" + str(
            self._host_name
        ) + "/" + self._port + route.get_route()
        print("\t--- FireApi Server ---\nlistening at " + endpoint)

    fn __accept_connection(borrowed self) raises -> Connection:
        let connAddr = self._py_socket.accept()
        return Connection(connAddr)

    fn __run_http_server(borrowed self) raises -> None:
        let httpd = self._modules.http.HTTPServer(
            (self._host_addr, self._port+1), 
            self._modules.http.SimpleHTTPRequestHandler,
        )
        _ = httpd.serve_forever()

    fn run[T: Route](borrowed self: Self, route: T) raises -> None:
        self.__bind_pySocket()
        self.__print_running[T](route=route)
        # _ = self._py_socket.listen()
        self.__run_http_server()

        # accept incoming connections
        let connection: Connection = self.__accept_connection()
        while True:
            # recieve data from the accepted connection
            let request_str: String = connection.revieve_data()  # 1024 bytes by default
            if not request_str:
                break

            # make a request object that can be passed into the users endpoint
            let request = Request(body=request_str)

            if not request.is_valid():
                let response = Response(
                    status_code=505,
                    body="bad request, not valid",
                )
                # return to the user
                break

            # if the request is the wrong kind of request for this api
            if route.get_method() != request.method():
                break

            # if it is valid

            break

        connection.close()
        self.__close_socket()
