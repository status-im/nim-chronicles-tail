import
  macros, os, chronicles, strformat

const
  nim_compiler_path {.strdefine.} = "nim"

type
  InstantiationInfo = tuple[filename: string, line: int, column: int]

macro compileJsImpl(callerInfo: static InstantiationInfo,
                    sourceFile: static string,
                    nimOptions: static string = ""): untyped =
  var
    fullSourceFile = callerInfo.filename.splitFile.dir / sourceFile
    targetFile = fullSourceFile & ".js"
    nimCmd = &"{nim_compiler_path} {nimOptions} js -o:{targetFile} {fullSourceFile}"

  let (output, status) = gorgeEx nimCmd
  if status != 0: error &"Compiling {sourceFile} failed:\n" & output

  result = newLit(staticRead targetFile)

template compileJs*(src: static string, nimOptions: string): string =
  compileJsImpl(instantiationInfo(-1, fullPaths = true), src, nimOptions)

template useTailPlugin*(stream: type, src: static string) =
  const pluginSrc = compileJsImpl(instantiationInfo(-1, fullPaths = true), src)
  stream.log LogLevel.NONE, "$chronicles", cmd = "loadPlugin", pluginSrc

