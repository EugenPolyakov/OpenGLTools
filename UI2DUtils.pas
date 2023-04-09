unit UI2DUtils;

interface

uses
  System.Types, System.SysUtils, System.Generics.Collections, OpenGL, OpenGLUtils,
  RecordUtils;

type
  TTexturesParameters = record
    Left, Top, Right, Bottom: Single;
    AttributeIndex: Integer;
    constructor Create(Index: Integer; ALeft: Single = 0; ATop: Single = 0; ARight: Single = 1; ABottom: Single = 1);
  end;

  TBilboard = record
    ShaderBlock: TShaderBlock;
    Textures: TTexturesInfo;
  end;
  PBilboard = ^TBilboard;

  TMatrixUniformExtension = record
    Transpose: Boolean;
    Count: GLsizei;
  end;

  TUniformBlockInfo = record
    UniformType: TUniformType;
    Size: Integer;
    Matrix: TMatrixUniformExtension;
    Name: AnsiString;
    constructor Create(const AName: AnsiString; AUniformType: TUniformType;
        ASize: Integer);
  end;

  TAttributeInfo = record
    Index: GLuint;
    Name: AnsiString;
    constructor Create(const AName: AnsiString; AIndex: Integer);
  end;

  TUniformStorage = record
    Info: TUniformInfo;
    UniformType: TUniformType;
  end;

  TProgramBlockInformation = record
    UniformInfo: TArray<TUniformBlockInfo>;
    Attribs: TArray<TAttributeInfo>;
    constructor Create(const AUniformInfo: array of TUniformBlockInfo;
        const AAttribs: array of TAttributeInfo);
  end;

  TUniformInformation = procedure (out Info: TProgramBlockInformation);

  TShaderPattern = record
    Pattern: AnsiString;
    BlockInfo: TProgramBlockInformation;
    constructor Create(const APattern: AnsiString; const ABlockInfo: TProgramBlockInformation);
  end;

  TShaderStorage = record
    Shader: TProgramInfo;
    Uniform: TArray<TUniformStorage>;
    MatrixExtension: TArray<TMatrixUniformExtension>;
    function GenerateShaderBlock: TShaderBlock;
  end;

  TProgramGenerator = class
  private
    FKnownPattern: TPrefixStringTree<TShaderPattern>;//TDictionary<Char, TShaderPattern>;
    FGenerated: TDictionary<string, TShaderStorage>;
    procedure FreeShader(Sender: TObject; const Item: TShaderStorage; Action: TCollectionNotification); overload;
    procedure FreeShader(const Item: TShaderStorage); overload;
  protected
    function GenerateProgramCode(const Shaders: array of string;
        const Types: array of {$IFDEF OGL_USE_ENUMS}TShaderType{$ELSE}GLenum{$ENDIF}): string;
  public
    procedure SetPattern(const C: string; const Shader: AnsiString; const BlockInfo: TProgramBlockInformation); overload;
    procedure SetPattern(const C: string; const Shader: AnsiString); overload;
    function Generate(Vertex, Fragment: string): TShaderStorage; overload;
    function Generate(const Shaders: array of string;
        const Types: array of {$IFDEF OGL_USE_ENUMS}TShaderType{$ELSE}GLenum{$ENDIF}): TShaderStorage; overload;
    procedure FreeContext;
    constructor Create;
    destructor Destroy; override;
  end;

const
  AttributeVertex = 0;
  AttributeTextureCoord = 1;

procedure DrawBilboard(const R: TRect; var ObjectInfo: TBilboard); overload;
procedure DrawBilboard(const R: TRect; var ObjectInfo: TBilboard; const TextureParams: array of TTexturesParameters); overload;
procedure DrawBilboard(const R: TRect; const TextureParams: array of TTexturesParameters); overload;

function ProgramGenerator: TProgramGenerator;

implementation

var
  GlobalProgramGenerator: TProgramGenerator = nil;

function ProgramGenerator: TProgramGenerator;
begin
  if GlobalProgramGenerator = nil then
    GlobalProgramGenerator:= TProgramGenerator.Create;
  Result:= GlobalProgramGenerator;
end;

procedure DrawBilboard(const R: TRect; const TextureParams: array of TTexturesParameters);
var i: Integer;
begin
  glBegin({$IFDEF OGL_USE_ENUMS}TPrimitiveType.{$ENDIF}GL_TRIANGLE_STRIP);
  for i := 0 to High(TextureParams) do with TextureParams[i] do
    glVertexAttrib2f(AttributeIndex, Left, Top);
  glVertexAttrib2f(AttributeVertex, R.Left, R.Top);

  for i := 0 to High(TextureParams) do with TextureParams[i] do
    glVertexAttrib2f(AttributeIndex, Left, Bottom);
  glVertexAttrib2f(AttributeVertex, R.Left, R.Bottom);

  for i := 0 to High(TextureParams) do with TextureParams[i] do
    glVertexAttrib2f(AttributeIndex, Right, Top);
  glVertexAttrib2f(AttributeVertex, R.Right, R.Top);

  for i := 0 to High(TextureParams) do with TextureParams[i] do
    glVertexAttrib2f(AttributeIndex, Right, Bottom);
  glVertexAttrib2f(AttributeVertex, R.Right, R.Bottom);
  glEnd;
end;

procedure DrawBilboard(const R: TRect; var ObjectInfo: TBilboard; const TextureParams: array of TTexturesParameters);
begin
  GetViewPortSize(ObjectInfo.ShaderBlock._FloatUniforms[0].Value);
  ObjectInfo.ShaderBlock.PrepareToDraw;
  ObjectInfo.Textures.Activate;
  DrawBilboard(R, TextureParams);
end;

procedure DrawBilboard(const R: TRect; var ObjectInfo: TBilboard);
var tp: TTexturesParameters;
begin
  if ObjectInfo.Textures._Textures[0].Texture.Target <> {$IFDEF OGL_USE_ENUMS}TTextureTarget.{$ENDIF}GL_TEXTURE_2D then
    tp:= TTexturesParameters.Create(AttributeTextureCoord, 0, 0, R.Width, R.Height)
  else
    tp:= TTexturesParameters.Create(AttributeTextureCoord);
  DrawBilboard(R, ObjectInfo, [tp]);
end;

{ TTexturesParameters }

constructor TTexturesParameters.Create(Index: Integer; ALeft, ATop, ARight,
  ABottom: Single);
begin
  AttributeIndex:= Index;
  Left:= ALeft;
  Top:= ATop;
  Right:= ARight;
  Bottom:= ABottom;
end;

{ TShaderStorage }

function TShaderStorage.GenerateShaderBlock: TShaderBlock;
var FloatUniforms: TArray<TUniformValue<GLfloat>>;
    IntegerUniforms: TArray<TUniformValue<GLint>>;
    MatrixUniforms: TArray<TUniformMatrixValue>;
    fCount, iCount, mCount: Integer;
  i: Integer;
begin
  fCount:= 0;
  iCount:= 0;
  mCount:= 0;
  for i := 0 to High(Uniform) do
    case Uniform[i].UniformType of
      utInteger: Inc(iCount);
      utFloat: Inc(fCount);
      utMatrix: Inc(mCount);
    end;
  SetLength(FloatUniforms, fCount);
  SetLength(IntegerUniforms, iCount);
  SetLength(MatrixUniforms, mCount);
  fCount:= 0;
  iCount:= 0;
  mCount:= 0;
  for i := 0 to High(Uniform) do
    case Uniform[i].UniformType of
      utInteger: begin
        IntegerUniforms[iCount].Info:= Uniform[i].Info;
        SetLength(IntegerUniforms[iCount].Value, Uniform[i].Info.Size);
        Inc(iCount);
      end;
      utFloat: begin
        FloatUniforms[fCount].Info:= Uniform[i].Info;
        SetLength(FloatUniforms[fCount].Value, Uniform[i].Info.Size);
        Inc(fCount);
      end;
      utMatrix: begin
        MatrixUniforms[mCount].MatrixInfo.Info:= Uniform[i].Info;
        MatrixUniforms[mCount].MatrixInfo.Transpose:= MatrixExtension[mCount].Transpose;
        MatrixUniforms[mCount].MatrixInfo.Count:= MatrixExtension[mCount].Count;
        SetLength(MatrixUniforms[mCount].Value, Uniform[i].Info.Size * MatrixUniforms[mCount].MatrixInfo.Count);
        Inc(mCount);
      end;
    end;
  Result.Create(Shader._Program, IntegerUniforms, FloatUniforms, MatrixUniforms);
end;

{ TProgramGenerator }

constructor TProgramGenerator.Create;
begin
  //FKnownPattern:= TDictionary<Char, TShaderPattern>.Create;
  FGenerated:= TDictionary<string, TShaderStorage>.Create;

  SetPattern('#120', '#version 120');
  SetPattern('{', 'void main(){');
  SetPattern('}', '}');

  SetPattern('!', 'precision highp float;');
  SetPattern('Upal', 'uniform sampler1D Palette;',
    TProgramBlockInformation.Create([TUniformBlockInfo.Create('Palette', utInteger, 1)], []));
  SetPattern('It2', 'varying vec2 TexCoord;');
  SetPattern('Um2', 'uniform sampler2D Map;',
    TProgramBlockInformation.Create([TUniformBlockInfo.Create('Map', utInteger, 1)], []));
  SetPattern('fPal2', '  float TexColor = texture2D(Map, TexCoord).x;');
  SetPattern('PalDiscard', '  if (TexColor < 1.0 / 255.0) discard;');
  SetPattern('Fpal', '  gl_FragColor = texture1D(Palette, TexColor);');
  SetPattern('Ftex2',  '  gl_FragColor = texture2D(Map, TexCoord);');

  SetPattern('IOt2', 'attribute vec2 aTexCoord;'#13#10'varying vec2 TexCoord;',
    TProgramBlockInformation.Create([], [TAttributeInfo.Create('aTexCoord', 1)]));
  SetPattern('Screen', 'uniform vec4 Screen;',
    TProgramBlockInformation.Create([TUniformBlockInfo.Create('Screen', utFloat, 4)], []));
  SetPattern('Iv2', 'attribute vec2 aVertex;',
    TProgramBlockInformation.Create([], [TAttributeInfo.Create('aVertex', 0)]));
  SetPattern('Vex', '  gl_Position = vec4(aVertex * 2.0 / Screen.xy - Screen.zw, 0.0, 1.0);');
  SetPattern('Tex', '	 TexCoord = aTexCoord;');
end;

destructor TProgramGenerator.Destroy;
begin
  //FKnownPattern.Free;
  FGenerated.Free;
  inherited;
end;

procedure TProgramGenerator.FreeContext;
begin
  FGenerated.OnValueNotify:= FreeShader;
  FGenerated.Clear;
  FGenerated.OnValueNotify:= nil;
end;

procedure TProgramGenerator.FreeShader(const Item: TShaderStorage);
var
  i: Integer;
begin
  glDeleteProgram(Item.Shader._Program);
  for i := 0 to High(Item.Shader._Shaders) do
    glDeleteShader(Item.Shader._Shaders[i]);
end;

procedure TProgramGenerator.FreeShader(Sender: TObject;
  const Item: TShaderStorage; Action: TCollectionNotification);
begin
  if Action = cnRemoved then
    FreeShader(Item);
end;

function TProgramGenerator.Generate(const Shaders: array of string;
  const Types: array of {$IFDEF OGL_USE_ENUMS}TShaderType{$ELSE}GLenum{$ENDIF}): TShaderStorage;
var Shader: TListRecord<PAnsiChar>;
    i, uCount, mCount: Integer;
    Attribs: TArray<TAttributeInfo>;
    Uniforms: TArray<TUniformBlockInfo>;
    CompiledShaders: array of GLuint;
    Code, Err, s: string;
    p: GLuint;
    link: Integer;
    j, k, l: Integer;
    sorted: array of GLenum;
    tmp: GLenum;
begin
  SetLength(sorted, Length(Types));
  for i := 0 to High(Types) do
    sorted[i]:= GLenum(Types[i]);
  for i := 0 to High(Types) - 1 do
    for j := i + 1 to High(Types) do
      if sorted[i] < sorted[j] then begin
        tmp:= sorted[i];
        sorted[i]:= sorted[j];
        sorted[j]:= tmp;
      end;
  Code:= '';
  for i := 0 to High(Types) do
    for j := 0 to High(Types) do
      if sorted[i] = Types[j] then begin
        Code:= Code + Shaders[j];
        Break;
      end;
  if not FGenerated.TryGetValue(Code, Result) then begin
    mCount:= 0;
    SetLength(CompiledShaders, Length(Shaders));
    for l := 0 to High(Shaders) do
      for k := 0 to High(Types) do
        if sorted[l] = Types[k] then begin
          Shader.Count:= 0;
          FKnownPattern.Reset(Shaders[k]);
          while not FKnownPattern.IsEnd do
            with FKnownPattern.NextToken do begin
              Shader.Add(Pointer(Pattern));
              Uniforms:= Concat(Uniforms, BlockInfo.UniformInfo);
              for j := 0 to High(BlockInfo.UniformInfo) do
                if BlockInfo.UniformInfo[j].UniformType = utMatrix then
                  Inc(mCount);
              Attribs:= Concat(Attribs, BlockInfo.Attribs);
            end;
          Shader.TrimExcess;
          CompiledShaders[k]:= CreateShader(Types[k], Shader.List);
        end;
    try
      p:= glCreateProgram;
      if p = 0 then
        RaiseOpenGLError;
      Result.Shader.Create(p, CompiledShaders);
      Result.Shader.AttachAll;
      for i := 0 to High(Attribs) do
        glBindAttribLocation(Result.Shader._Program, Attribs[i].Index, Pointer(Attribs[i].Name));

      Err:= '';
      for i := 0 to High(Types) do begin
        s:= GetShaderLog(Result.Shader._Shaders[i]);
        LogOutput(TProgramGenerator, Format('InitializeProgram %s [%x]', [Code, sorted[i]]), s);
        Err:= Err + #13#10 + s;
      end;
      glLinkProgram(Result.Shader._Program);
      glGetProgramiv(Result.Shader._Program, {$IFDEF OGL_USE_ENUMS}TProgramPropertyARB.{$ENDIF}GL_LINK_STATUS, @link);
      if link = 0 then begin
        s:= GetProgramLog(Result.Shader._Program);
        LogOutput(TProgramGenerator, Format('InitializeProgram %s link', [Code]), s);
        RaiseOpenGLError(0, s + #13#10 + Err);
      end;

      SetLength(Result.Uniform, Length(Uniforms));
      SetLength(Result.MatrixExtension, mCount);
      mCount:= 0;

      for i := 0 to High(Result.Uniform) do begin
        Result.Uniform[i].Info.Index:= glGetUniformLocation(Result.Shader._Program, Pointer(Uniforms[i].Name));
        Result.Uniform[i].Info.Size:= Uniforms[i].Size;
        Result.Uniform[i].UniformType:= Uniforms[i].UniformType;
        if Uniforms[i].UniformType = utMatrix then begin
          Result.MatrixExtension[mCount]:= Uniforms[i].Matrix;
          Inc(mCount);
        end;
      end;
      LogOutput(TProgramGenerator, Format('InitializeProgram %s Program', [Code]), GetProgramLog(Result.Shader._Program));
    except
      FreeShader(Result);
      raise;
    end;

    FGenerated.Add(Code, Result);
  end;
end;

function TProgramGenerator.Generate(Vertex, Fragment: string): TShaderStorage;
begin
  Result:= Generate([Vertex, Fragment], [{$IFDEF OGL_USE_ENUMS}TShaderType.{$ENDIF}GL_VERTEX_SHADER,
      {$IFDEF OGL_USE_ENUMS}TShaderType.{$ENDIF}GL_FRAGMENT_SHADER]);
end;

function TProgramGenerator.GenerateProgramCode(const Shaders: array of string;
  const Types: array of {$IFDEF OGL_USE_ENUMS}TShaderType{$ELSE}GLenum{$ENDIF}): string;
var i: Integer;
    sorted: array of GLenum;
    tmp: GLenum;
    j: Integer;
begin
  SetLength(sorted, Length(Types));
  for i := 0 to High(Types) do
    sorted[i]:= GLenum(Types[i]);
  for i := 0 to High(Types) - 1 do
    for j := i + 1 to High(Types) do
      if sorted[i] < sorted[j] then begin
        tmp:= sorted[i];
        sorted[i]:= sorted[j];
        sorted[j]:= tmp;
      end;
  Result:= '';
  for i := 0 to High(Types) do
    for j := 0 to High(Types) do
      if sorted[i] = Types[j] then begin
        Result:= Result + Shaders[j];
        Break;
      end;
end;

procedure TProgramGenerator.SetPattern(const C: string; const Shader: AnsiString);
var t: TProgramBlockInformation;
begin
  FKnownPattern.AddOrSetValue(C, TShaderPattern.Create(Shader + #13#10, t));
end;

procedure TProgramGenerator.SetPattern(const C: string; const Shader: AnsiString;
    const BlockInfo: TProgramBlockInformation);
begin
  FKnownPattern.AddOrSetValue(C, TShaderPattern.Create(Shader + #13#10, BlockInfo));
end;

{ TShaderPattern }

constructor TShaderPattern.Create(const APattern: AnsiString;
  const ABlockInfo: TProgramBlockInformation);
begin
  Pattern:= APattern;
  BlockInfo:= ABlockInfo;
end;

{ TProgramBlockInformation }

constructor TProgramBlockInformation.Create(
  const AUniformInfo: array of TUniformBlockInfo;
  const AAttribs: array of TAttributeInfo);
var i: Integer;
begin
  SetLength(UniformInfo, Length(AUniformInfo));
  for i := 0 to High(AUniformInfo) do
    UniformInfo[i]:= AUniformInfo[i];
  SetLength(Attribs, Length(AAttribs));
  for i := 0 to High(AAttribs) do
    Attribs[i]:= AAttribs[i];
end;

{ TUniformBlockInfo }

constructor TUniformBlockInfo.Create(const AName: AnsiString;
  AUniformType: TUniformType; ASize: Integer);
begin
  Name:= AName;
  UniformType:= AUniformType;
  Size:= ASize
end;

{ TAttributeInfo }

constructor TAttributeInfo.Create(const AName: AnsiString; AIndex: Integer);
begin
  Name:= AName;
  Index:= AIndex;
end;

initialization

finalization

  FreeAndNil(GlobalProgramGenerator);

end.
