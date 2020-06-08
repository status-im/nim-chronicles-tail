import
  os, asyncdispatch, asynctools/asyncpipe

export
  asyncpipe

when defined(windows):
  import winlean

  proc writeToPipe(p: AsyncPipe, data: pointer, nbytes: int) =
    if WriteFile(p.getWriteHandle, data, int32(nbytes), nil, nil) == 0:
      raiseOsError(osLastError())

else:
  import posix

  proc writeToPipe(p: AsyncPipe, data: pointer, nbytes: int) =
    if posix.write(p.getWriteHandle, data, cint(nbytes)) < 0:
      raiseOsError(osLastError())

proc writePipeFrame*(p: AsyncPipe, data: string) =
  var dataLen = data.len
  if dataLen > 0:
    p.writeToPipe(addr(dataLen), sizeof(dataLen))
    p.writeToPipe(unsafeAddr data[0], data.len)

proc readPipeFrame*(p: AsyncPipe): Future[string] {.async.} =
  var frameSize: int
  var bytesRead = await p.readInto(addr(frameSize), sizeof(frameSize))
  if bytesRead != sizeof(frameSize):
    raiseOsError(osLastError())

  result = newString(frameSize)

  bytesRead = await p.readInto(addr result[0], frameSize)
  if bytesRead != frameSize:
    raiseOsError(osLastError())

