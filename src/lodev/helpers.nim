import httputils, times

proc fromInt*(code: int): HttpCode =
  ## Returns ``code`` as HttpCode value.
  case code
    of 100: return Http100
    of 101: return Http101
    of 200: return Http200
    of 201: return Http201
    of 202: return Http202
    of 203: return Http203
    of 204: return Http204
    of 205: return Http205
    of 206: return Http206
    of 300: return Http300
    of 301: return Http301
    of 302: return Http302
    of 303: return Http303
    of 304: return Http304
    of 305: return Http305
    of 307: return Http307
    of 400: return Http400
    of 401: return Http401
    of 403: return Http403
    of 404: return Http404
    of 405: return Http405
    of 406: return Http406
    of 407: return Http407
    of 408: return Http408
    of 409: return Http409
    of 410: return Http410
    of 411: return Http411
    of 412: return Http412
    of 413: return Http413
    of 414: return Http414
    of 415: return Http415
    of 416: return Http416
    of 417: return Http417
    of 418: return Http418
    of 421: return Http421
    of 422: return Http422
    of 426: return Http426
    of 428: return Http428
    of 429: return Http429
    of 431: return Http431
    of 451: return Http451
    of 500: return Http500
    of 501: return Http501
    of 502: return Http502
    of 503: return Http503
    of 504: return Http504
    of 505: return Http505
    else: return Http505

proc datetime*(): string =
  result = "[" & getDateStr() & "T" & getClockStr() & "] "
