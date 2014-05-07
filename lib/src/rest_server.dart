part of rest;

class RestServer {
  List<RestResource> _resources = new List<RestResource>();

  final Logger log = new Logger('RestServer');

  RestContentTypes _AvailableContentTypes = new RestContentTypes();

  RestServer() {
    log.info("Rest server instance created");
  }

  void Start([InternetAddress address = null, int port = 8080]) {

    if (address == null) {
      address = InternetAddress.LOOPBACK_IP_V4;
    }

    HttpServer.bind(address, port).then((server) {
      log.info("Serving at ${server.address}:${server.port}");
      server.listen(AnswerRequest);
    });

  }

  void AddDefaultContentType(ContentType type) {
    this._AvailableContentTypes.AddDefaultContentType(type);
  }

  void AddContentType(ContentType type) {
    this._AvailableContentTypes.AddContentType(type);
  }

  void AddResource(RestResource resource) {
    this._resources.add(resource);
  }

  void AnswerRequest(HttpRequest request) {
    Stopwatch stopwatch = new Stopwatch()..start();
    StringBuffer output = new StringBuffer();
    Future fut = new Future.sync(() {
      request.response.headers.contentType = this._AvailableContentTypes.GetRequestedContentType(request);

      for (RestResource resource in this._resources) {
        if (resource.Matches(request.uri.path)) {
          return resource.Trigger(request, request.response.headers.contentType, request.uri.path);
        }
      }
      throw new RestException(404, "The requested resource was not found");
    }).then((data) {
      if (data != null) {
        output.write(data);
      }
    }).catchError((e, st) {
      log.severe(e.toString(), e, st);
      output.write(this._ProcessError(request.response, e, st));
    }).whenComplete(() {
      // Last chance to write a header, so we write the processing time
      request.response.headers.add("X-Processing-Time", stopwatch.elapsed.toString());
      request.response.headers.add("Access-Control-Allow-Origin", "*");
      if (output.length == 0) { // If the content length is 0, and if the current status code is 200, then we send a 204
        if (request.response.statusCode == 200) {
          request.response.statusCode = 204;
        }
      } else {
        request.response.contentLength = output.length;
        request.response.write(output);
      }
      request.response.close();
      stopwatch.stop();
    });
  }

  String _ProcessError(HttpResponse response, Object e, [StackTrace st = null]) {
    Map<String, Object> output = new Map<String, Object>();

    output["message"] = e.toString();
    if (e is RestException) {
      response.statusCode = e.Code;
      output["code"] = e.Code;
    } else {
      response.statusCode = 500;
      output["code"] = 500;
    }
    if (st != null) {
      output["stack_trace"] = st.toString();
    }

    return JSON.encode(output);
  }

}