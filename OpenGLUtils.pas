unit OpenGLUtils;

interface
uses SysUtils, Math, Windows, {$IFDEF CUSTOMOPENGL}CustomOpenGL{$ELSE}OpenGL{$ENDIF}, {glExt, wglExt,{VecAlgebra,} System.Generics.Collections,
  RecordUtils, SysTypes, WinapiUtils, Threading, SysUtilsExtensions, System.UITypes,
  System.Classes;

{$IFDEF USE10AS13}
{$DEFINE SKIP10}
{$ENDIF}

type
  TFloatCamera = class
  private
    FTarget, FOffset, FUp, FPos: array [0..2] of Single;
    bestRange, minRange, maxRange, prRange: Single;
    FRotZ: Single;
    bestAzimuth, minAzimuth, maxAzimuth, prAzimuth: Single;
    bestElevation, minElevation, maxElevation, prElevation: Single;
  protected
    procedure SetRotZ(Angle: Single);
    function GetGA: Single;
    procedure SetGA(Angle: Single);
    procedure SetAzimuth(Angle: Single);
  public
    property Azimuth: Single read prAzimuth write SetAzimuth;
    constructor Create;
    property RotZ: Single read FRotZ write SetRotZ;
    property GlobalAzimuth: Single read GetGA write SetGA;
  end;

  TGLContext = record
    GLRC: HGLRC;
    PS: TPaintStruct;
    PF: TPixelFormatDescriptor;
    procedure DeleteContext(Throw: Boolean = False);
    function CreateOpenGLContext(DC: HDC; MajorVersion, MinorVersion, Flags, ProfileMask: LongWord; Throw: Boolean = True): Integer; overload;
    function CreateOpenGLContext(DC: HDC; Throw: Boolean = True): Integer; overload;
    procedure MakeCurrent(DC: HDC; Throw: Boolean = True);
  end;

  TGLRenderer = class
  private
  protected
  public
    procedure Reset;
    procedure Initialize;
    constructor Create;
    destructor Destroy; override;
  end;

  TVBOBindFunction = (bfDefault, bfInteger, bfDouble);
  TVBOElementFormat = record
    Normalized: Boolean;
    Size: GLint;
    Stride: GLsizei;
    Offset: Integer;
  {$IFDEF OGL_USE_ENUMS}
  case BindFunction: TVBOBindFunction of
    bfDefault: (FloatType: TVertexAttribPointerType);
    bfInteger: (IntegerType: TVertexAttribIType);
    //bfDouble:;
  {$ELSE}
    BindFunction: TVBOBindFunction;
    DataType: GLenum;
  {$ENDIF}
  end;

  TVBOElementFormats = class
  private class var
    FElementFormatV2f: TArray<TVBOElementFormat>;
    FElementFormatV3f: TArray<TVBOElementFormat>;
    FElementFormatV2fT2f: TArray<TVBOElementFormat>;
    FElementFormatV3fT2f: TArray<TVBOElementFormat>;
    FElementFormatV2fT2fC4f: TArray<TVBOElementFormat>;
    FElementFormatV4fT2fC4f: TArray<TVBOElementFormat>;
    FElementFormatV4fT3fC4f: TArray<TVBOElementFormat>;
  public
    class constructor Create;
    class property ElementFormatV2f: TArray<TVBOElementFormat> read FElementFormatV2f;
    class property ElementFormatV3f: TArray<TVBOElementFormat> read FElementFormatV3f;
    class property ElementFormatV2fT2f: TArray<TVBOElementFormat> read FElementFormatV2fT2f;
    class property ElementFormatV3fT2f: TArray<TVBOElementFormat> read FElementFormatV3fT2f;
    class property ElementFormatV2fT2fC4f: TArray<TVBOElementFormat> read FElementFormatV2fT2fC4f;
    class property ElementFormatV4fT2fC4f: TArray<TVBOElementFormat> read FElementFormatV4fT2fC4f;
    class property ElementFormatV4fT3fC4f: TArray<TVBOElementFormat> read FElementFormatV4fT3fC4f;
  end;

  TVBOElements = record
  private
    _Elements: GLuint;
    _ElementsFormat: TArray<TVBOElementFormat>;
  public
    property Elements: GLuint read _Elements;
    constructor Create(const AElementsFormat: TArray<TVBOElementFormat>; AElements: GLuint);
    constructor New(const AElementsFormat: TArray<TVBOElementFormat>);
    constructor Copy(const AElement: TVBOElements);
    function ElementFormatsCount: Integer; inline;
    procedure Bind;
    procedure EnableAttributes(const AttribIndicies: array of GLuint);
    procedure Disable(const AttribIndicies: array of GLuint);
    procedure UnBind; inline;
    procedure FreeContext; inline;
  end;

  TVBOIndices = record
  private
    _Indices: GLuint;
    _IndicesType: {$IFDEF OGL_USE_ENUMS}TDrawElementsType{$ELSE}GLenum{$ENDIF};
    _IndicesCount: GLsizei;
    _IndicesStride: GLsizei;
  public
    property Indices: GLuint read _Indices;
    constructor Create(AIndeces: GLuint; AIndecesType: {$IFDEF OGL_USE_ENUMS}TDrawElementsType{$ELSE}GLenum{$ENDIF};
        AIndecesCount, AIndecesStride: GLsizei);
    constructor New(AIndecesType: {$IFDEF OGL_USE_ENUMS}TDrawElementsType{$ELSE}GLenum{$ENDIF};
        AIndecesCount, AIndecesStride: GLsizei);
    constructor Copy(const AIndeces: TVBOIndices);
    procedure Bind; inline;
    procedure UnBind; inline;
    procedure FreeContext; inline;
    procedure Draw(mode: {$IFDEF OGL_USE_ENUMS}TPrimitiveType{$ELSE}GLenum{$ENDIF};
        BeginIndex, EndIndex, IndicesOffset, IndicesCount: GLsizei); inline;
  end;

  TVertexBufferObject = record
  private
    _Elements: TVBOElements;
    _Indices: TVBOIndices;
    _IsQuads: Boolean;
  public
    constructor Create(const AElementsFormat: TArray<TVBOElementFormat>; AIndeces, AElements: GLuint;
        AIndecesType: {$IFDEF OGL_USE_ENUMS}TDrawElementsType{$ELSE}GLenum{$ENDIF};
        AIndecesCount, AIndecesStride: GLsizei; AIsQuads: Boolean);
    constructor CreateQuadsSurface(const AVector: array of GLfloat);
    constructor New(const AElementsFormat: TArray<TVBOElementFormat>;
        AIndecesType: {$IFDEF OGL_USE_ENUMS}TDrawElementsType{$ELSE}GLenum{$ENDIF};
        AIndecesCount, AIndecesStride: GLsizei; AIsQuads: Boolean);
    property Indices: GLuint read _Indices._Indices;
    property Elements: GLuint read _Elements._Elements;
    function ElementFormatsCount: Integer; inline;
    procedure Draw(const AttribIndicies: array of GLuint); overload;
    procedure Draw(BeginIndex, EndIndex, IndecesOffset, IndecesCount: GLsizei; const AttribIndicies: array of GLuint); overload;
    procedure FreeContext;
    procedure Bind; inline;
  end;

  TOGLTexture = record
    Target: {$IFDEF OGL_USE_ENUMS}TTextureTarget{$ELSE}GLenum{$ENDIF};//GL_TEXTURE_RECTANGLE_ARB
    Texture: GLuint;
    procedure Bind; inline;
    procedure Enable; inline;
    procedure FreeContext; inline;
  end;
  POGLTexture = ^TOGLTexture;

  TTextureBlock = record
    Index: {$IFDEF OGL_USE_ENUMS}TTextureUnit{$ELSE}GLenum{$ENDIF};//GL_TEXTURE0
    Texture: TOGLTexture;
    constructor Create(AIndex: {$IFDEF OGL_USE_ENUMS}TTextureUnit{$ELSE}GLenum{$ENDIF}; const ATexture: TOGLTexture);
  end;

  TFloatMatrix2x2 = array [0..1, 0..1] of GLfloat;
  TFloatMatrix3x3 = array [0..2, 0..2] of GLfloat;
  TFloatMatrix4x4 = array [0..3, 0..3] of GLfloat;

  TUniformInfo = record
    Index: GLint;
    Size: Integer;
  end;

  TUniformType = (utInteger, utFloat, utMatrix);

  TUniformMatrixInfo = record
    Info: TUniformInfo;
    Transpose: Boolean;
    Count: GLsizei;
  end;

  TUniformMatrixValue = record
    Value: TArray<GLfloat>;
    MatrixInfo: TUniformMatrixInfo;
  end;

  TUniformValue<T> = record
    Value: TArray<T>;
    Info: TUniformInfo;
  end;

  TShaderBlock = record
  //private
    _Program: GLuint;
    _IntegerUniforms: TArray<TUniformValue<GLint>>;
    _FloatUniforms: TArray<TUniformValue<GLfloat>>;
    _MatrixUniforms: TArray<TUniformMatrixValue>;
  public
    constructor Create(AProgram: GLuint;const AIntegerUniforms: TArray<TUniformValue<GLint>>;
        const AFloatUniforms: TArray<TUniformValue<GLfloat>>;
        const AMatrixUniforms: TArray<TUniformMatrixValue>);
    procedure PrepareToDraw;
  end;

  TTexturesInfo = record
  //private
    _Textures: TArray<TTextureBlock>;
  public
    constructor Create(const ATextures: TArray<TTextureBlock>); overload;
    constructor Create(const ATextures: array of TTextureBlock); overload;
    procedure Activate;
    procedure Deactivate;
  end;

  TDIP = record
  //private
    _Buffer: TVertexBufferObject;
    _InitShader: TShaderBlock;
    _Textures: TTexturesInfo;
    _AttribIndicies: TArray<GLuint>;
    _BeginIndex,
    _EndIndex,
    _IndicesOffset,
    _IndicesCount: GLsizei;
  public
    constructor Create(const ABuffer: TVertexBufferObject; const AInitShader: TShaderBlock;
        const ATextures: TTexturesInfo; const AAttribIndicies: TArray<GLuint>;
        ABeginIndex, AEndIndex, AIndecesOffset, AIndecesCount: GLsizei);
    procedure Draw;
  end;

  TPreparedText = record
    Buffer: TVertexBufferObject;
    LineEndSymbolIndex: TArray<GLintptr>;
    SymbolsCount: GLsizei;
    MaxWidth: Integer;
    procedure FreeContext;
  end;

  TBorderedText = record
    Prepared: TPreparedText;
    ReadyToDraw: TDIP;
    BoundRect: TRect;
    procedure Draw;
    procedure FreeContext;
  end;

  TProgramInfo = record
    _Program: GLuint;
    _Shaders: array of GLuint;
    constructor Create(AProgram: GLuint; const AShaders: array of GLuint);
    procedure AttachAll;
  end;

  TProgramDataInfo = record
    UniformInfos: TArray<TUniformInfo>;
    UniformMatrixInfo: TArray<TUniformMatrixInfo>;
  end;

  TVector2<T> = array [0..1] of T;
  TVector3<T> = array [0..2] of T;
  TVector4<T> = array [0..3] of T;
  TSquad2DCoord<T> = array [0..3] of TVector2<T>;
  TElementV2T2<T> = record
    Vector: TVector2<T>;
    TexCoord: TVector2<T>;
  end;
  TElementV2T2C4<T> = record
    Vector: TVector2<T>;
    TexCoord: TVector2<T>;
    ColorVex: TVector4<T>;
  end;
  TElementV4T2C4<T> = record
    Vector: TVector4<T>;
    TexCoord: TVector2<T>;
    ColorVex: TVector4<T>;
  end;
  TElementV4T3C4<T> = record
    Vector: TVector4<T>;
    TexCoord: TVector3<T>;
    ColorVex: TVector4<T>;
  end;

  TBitmapCharBlock = record
    ABC: array [0..$FF] of TABC;
    TexCoord: array [0..255] of TSquad2DCoord<GLfloat>;
    //Mesh: array [0..255, 0..3, 0..1] of Integer;
    Width: array [0..$FF] of Integer;
  end;
  PBitmapCharBlock = ^TBitmapCharBlock;

  TBitmapFontData = record
    CharTable: array [0..$10FF] of PBitmapCharBlock;
    TexWidth: Integer;
    TexHeight: Integer;
    Tex: GLuint;
    Height: Word;
    XOffset, YOffset: Integer;
    TexData: TArray<Byte>;
    procedure Clear;
  end;
  PBitmapFontData = ^TBitmapFontData;

  TTextAlign = (taJustify, taLeft, taRight, taCenterAlinment);

  TLineInfo = record
    OffsetX: Integer;
    SpaceWidth: Integer;
    constructor Create(AOffsetX, ASpaceWidth: Integer);
  end;

  TTextInfo = record
    LineEndSymbolIndex: TArray<GLintptr>;
    LinesAlignment: TArray<TLineInfo>;
    SymbolsCount: GLsizei;
    MaxWidth: Integer;
  end;

  TBitmapFontBase = class
  strict private
    FCurrentCharData: PBitmapFontData;
    FCharBuffers: array [0..1] of TBitmapFontData;
    FBMP: TBitmapGDI;
    FFont: TFontData;
    FHeight, FLineHeight: Integer;
    FRenderTask: ITask;
    FNeededLayers: TLockFreeStack<LongWord>;
    FShouldToggle: Boolean;
    FDefaultChar: UCS4Char;
  strict protected
    FTextures: TTexturesInfo;
    procedure GenerateTexture;
    procedure FillTexture(TexWidth, TexHeight: Integer; TexData: Pointer);
    procedure AddNewLayer(ALayer: Cardinal); inline;
    procedure Initialize(Sender: TObject);
    procedure ActualizeState;
    procedure ReadyToToggle; virtual;
    function GetCharInfo(AChar: UCS4Char): PBitmapCharBlock; //inline;
    //в этих функциях нет проверок
    function GetTextInfo(const AText: string; out AInfo: TTextInfo; DefaultWidth, SpaceWidth, MaxWidth: Integer; AAlign: TTextAlign; Wrap: Boolean): Boolean; overload;
    function GetTextInfoByIndex(const AText: string; out AInfo: TTextInfo; DefaultWidth, SpaceWidth, MaxWidth: Integer; AAlign: TTextAlign; Wrap: Boolean): Boolean; overload;
    function GetTextInfo(const AText: string; out AInfo: TTextInfo; DefaultWidth, SpaceWidth: Integer): Boolean; overload;
    function SkipControlSymbols(var TextPointer: PChar): Boolean; virtual;
  public
    function IsSameFornt(const AFont: TFontData): Boolean;
    property Height: Integer read FHeight;
    function TextureSymbolHeight: GLfloat;
    property LineHeight: Integer read FLineHeight;
    property DefaultChar: UCS4Char read FDefaultChar;
    function GetTextInfo(const AText: string; out AInfo: TTextInfo; MaxWidth: Integer; AAlign: TTextAlign; Wrap: Boolean): Boolean; overload;
    function GetTextInfo(const AText: string; out AInfo: TTextInfo): Boolean; overload;
    function GetTextSize(const AText: string; MaxWidth: Integer; AAlign: TTextAlign; Wrap: Boolean): TPoint;
    procedure FreeContext; virtual;
    constructor Create(const AFont: TFontData; const ADefaultCharAndStartLayers: string = #$FFFD);
    destructor Destroy; override;
  end;

  TBitmapFont = class (TBitmapFontBase)
  public const
    TFFS_Color : PAnsiChar = '#version 130'#13#10 +
      //'#if (__VERSION__ < 130)'#13#10 +
      //'#define in varying'#13#10 +
      //'#endif'#13#10 +
      //'#extension GL_ARB_texture_rectangle:enable'#13#10 +
      '#ifdef GL_ARB_texture_rg'#13#10 +
      '#define TextAlpha(M, T) (texture2DRect(M, T).x)'#13#10 +
      '#else'#13#10 +
      '#define TextAlpha(M, T) (texture(M, T).x)'#13#10 +
      '#endif'#13#10 +
      //'precision highp float;'#13#10 +
      'in vec2 Tex;'#13#10 +
      'uniform vec4 Color;'#13#10 +
      'uniform sampler2D Map;'#13#10 +
      'void main(){'#13#10 +
      ' float TexColor = TextAlpha(Map, Tex);'#13#10 +
      ' if (TexColor < 0.1) discard;'#13#10 +
      '	gl_FragColor = vec4(Color.xyz, TexColor * Color.w);'#13#10 +
      '}';
    TFVS_OfsColor : PAnsiChar = '#version 130'#13#10 +
      //'precision highp float;'#13#10 +
      'out vec2 Tex;'#13#10 +
      'in vec2 TexCoord;'#13#10 +
      'in vec2 Mesh;'#13#10 +
      'uniform vec3 Offsets;'#13#10 +
      'uniform vec2 Screen;'#13#10 +
      'void main ()'#13#10 +
      '{'#13#10 +
      '	gl_Position = vec4(((Mesh * Offsets.z + Offsets.xy) / Screen - 0.5) * 2.0, 0.0, 1.0);'#13#10 +
      '	Tex = TexCoord;'#13#10 +
      '}';
    MeshCoord = 0;
    TexCoord = 1;
  private class var
    FProgramFontOC: TProgramInfo;
    FScreenSizeUniform, FTextOffsetUniform, FColorUniform, FTextureUniform: TUniformInfo;
  protected
    //don't forget call ActualizeState before
    procedure PrepareTextWordWrap(const AText: string; const AInfo: TTextInfo; Default: PBitmapCharBlock; SpaceWidth: Integer; var Prepared: TPreparedText); overload;
  public
    function GetTextRect(const AText: string): TRect; inline;
    function GetTextSize(const AText: string): TSize;
    function GetTextHeight(const AText: string): Integer;
    function GetTextWidth(const AText: string): Integer;
    function PrepareText(const AText: string; out Prepared: TPreparedText): Boolean;
    function PrepareTextWordWrap(const AText: string; MaxWidth: Integer; Align: TTextAlign; out Prepared: TPreparedText): Boolean; overload;
    //function DrawTextRect(const AText: string; const ABoundRect: TRect; const AOffset: TSize; var APrepared: TDIP; AWordWrap: Boolean = False): Boolean;
    function PrepareTextRect(const AText: string; const ABoundRect: TRect; const AOffset: TPoint; out APrepared: TBorderedText; AColor: TColor; AScale: GLfloat = 1.0; AWordWrap: Boolean = False):Boolean;
    procedure UpdateTextOffset(var APrepared: TBorderedText; const AOffset: TPoint; AColor: TColor; AOpasity: GLfloat = 1.0; AScale: GLfloat = 1.0);
    procedure GenerateTextDIP(const Prepared: TPreparedText; var DIP: TDIP; AOffset: TPoint; AColor: TColor; AOpasity: GLfloat = 1.0; AScale: GLfloat = 1);
    constructor Create(const AFontName: string; AHeight: Integer; const ADefaultCharAndStartLayers: string = #$FFFD); overload;
    class procedure InitializeProgram;
  end;

  TOGLLogFunction = procedure (Self: Pointer; AClass: TClass; const AFunctionName, AMessage: string);
  TOGLLogFunctionObj = procedure (AClass: TClass; const AFunctionName, AMessage: string) of object;

const
  UnusedAttrib = GLuint(-1);

{procedure CreateCylinder(x, y, z, AngleX, AngleY, AngleZ, bR, tR, H: GLfloat;
  Slices, Stacks: Integer; n, tc, v: TList<Single>; ind: TList<LongInt>; Grad: Single = 360);
procedure CalcNormal(var nx, ny, nz: GLfloat; x1, y1, z1, x2, y2, z2,
  x3, y3, z3: GLfloat);
procedure Translate(var x, y, z: GLfloat; dx, dy, dz: GLfloat);
procedure Rotate(var x, y, z: GLfloat; ax, ay, az: GLfloat);
procedure Normalize(var nx, ny, nz: GLFloat);   }

function CreateOpenGL30Context(Handle: THandle; var GL: TGLContext): Integer;
procedure SetDCPixelFormat(DC : HDC; var PF: TPixelFormatDescriptor);
function CreateShader(_Type: {$IFDEF OGL_USE_ENUMS}TShaderType{$ELSE}GLenum{$ENDIF}; Res: PAnsiChar): GLuint; overload; inline;
function CreateShader(_Type: {$IFDEF OGL_USE_ENUMS}TShaderType{$ELSE}GLenum{$ENDIF}; Res: array of PAnsiChar): GLuint; overload;
procedure RaiseOpenGLError; inline; overload;
procedure RaiseOpenGLError(LastError: Integer); inline; overload;
procedure RaiseOpenGLError(LastError: Integer; const AdditionalInfo: string); overload;
function GetShaderLog(Shader: GLuint): string; overload;
procedure GetShaderLog(Shader: GLuint; out Result: AnsiString); overload;
function GetProgramLog(_Program: GLuint): string; overload;
procedure GetProgramLog(_Program: GLuint; out Result: AnsiString); overload;
procedure LogOutput(AClass: TClass; const AFunctionName, AMessage: string);
procedure LogOutputAllErrors(AClass: TClass; const AFunctionName: string);
procedure DebugLogOutputAllErrors(AClass: TClass; const AFunctionName: string); inline;
procedure SetViewPortSize(Width, Height: GLint);

function SetLogFunction(ALogFunction: TOGLLogFunction; ASelf: Pointer): TOGLLogFunctionObj; overload;
function SetLogFunction(ALogFunction: TOGLLogFunctionObj):TOGLLogFunctionObj; overload;

procedure GetViewPortSize(out Size: TArray<GLfloat>);

resourcestring
  SOGLError = 'OpenGL Error.  Code: %d.'+sLineBreak+'%s';

implementation

var
  GlobalViewPortSize: TArray<GLfloat> = [1920, -1080, 1, -1];
  GlobalViewPortSizeInteger: TArray<Integer> = [1920, 1080];

procedure GetViewPortSize(out Size: TArray<GLfloat>);
begin
  Pointer(Size):= Pointer(GlobalViewPortSize);
end;

const
    RawV2f : record
      Header: TDynArrayRec;
      Arr: array [0..0] of TVBOElementFormat;
    end = (Header: (RefCnt: -1; Length: 1); Arr: (
        (Normalized: False; Size: 2; Stride: 2 * SizeOf(GLfloat); Offset: 0; BindFunction: bfDefault; {$IFDEF OGL_USE_ENUMS}FloatType: TVertexAttribPointerType.{$ELSE}DataType: {$ENDIF}GL_FLOAT;)
        );
      );
    RawV3f : record
      Header: TDynArrayRec;
      Arr: array [0..0] of TVBOElementFormat;
    end = (Header: (RefCnt: -1; Length: 1); Arr: (
        (Normalized: False; Size: 3; Stride: 3 * SizeOf(GLfloat); Offset: 0; BindFunction: bfDefault; {$IFDEF OGL_USE_ENUMS}FloatType: TVertexAttribPointerType.{$ELSE}DataType: {$ENDIF}GL_FLOAT;)
        );
      );
    RawV2fT2f : record
      Header: TDynArrayRec;
      Arr: array [0..1] of TVBOElementFormat;
    end = (Header: (RefCnt: -1; Length: 2); Arr: (
        (Normalized: False; Size: 2; Stride: (2 + 2) * SizeOf(GLfloat); Offset: 0; BindFunction: bfDefault; {$IFDEF OGL_USE_ENUMS}FloatType: TVertexAttribPointerType.{$ELSE}DataType: {$ENDIF}GL_FLOAT;),
        (Normalized: False; Size: 2; Stride: (2 + 2) * SizeOf(GLfloat); Offset: 2 * SizeOf(GLfloat); BindFunction: bfDefault; {$IFDEF OGL_USE_ENUMS}FloatType: TVertexAttribPointerType.{$ELSE}DataType: {$ENDIF}GL_FLOAT;)
        );
      );
    RawV2fT2fC4f : record
      Header: TDynArrayRec;
      Arr: array [0..2] of TVBOElementFormat;
    end = (Header: (RefCnt: -1; Length: 3); Arr: (
        (Normalized: False; Size: 2; Stride: (2 + 2 + 4) * SizeOf(GLfloat); Offset: 0; BindFunction: bfDefault; {$IFDEF OGL_USE_ENUMS}FloatType: TVertexAttribPointerType.{$ELSE}DataType: {$ENDIF}GL_FLOAT;),
        (Normalized: False; Size: 2; Stride: (2 + 2 + 4) * SizeOf(GLfloat); Offset: 2 * SizeOf(GLfloat); BindFunction: bfDefault; {$IFDEF OGL_USE_ENUMS}FloatType: TVertexAttribPointerType.{$ELSE}DataType: {$ENDIF}GL_FLOAT;),
        (Normalized: False; Size: 4; Stride: (2 + 2 + 4) * SizeOf(GLfloat); Offset: (2 + 2) * SizeOf(GLfloat); BindFunction: bfDefault; {$IFDEF OGL_USE_ENUMS}FloatType: TVertexAttribPointerType.{$ELSE}DataType: {$ENDIF}GL_FLOAT;)
        );
      );
    RawV3fT2f : record
      Header: TDynArrayRec;
      Arr: array [0..1] of TVBOElementFormat;
    end = (Header: (RefCnt: -1; Length: 2); Arr: (
        (Normalized: False; Size: 3; Stride: (3 + 2) * SizeOf(GLfloat); Offset: 0; BindFunction: bfDefault; {$IFDEF OGL_USE_ENUMS}FloatType: TVertexAttribPointerType.{$ELSE}DataType: {$ENDIF}GL_FLOAT;),
        (Normalized: False; Size: 2; Stride: (3 + 2) * SizeOf(GLfloat); Offset: 3 * SizeOf(GLfloat); BindFunction: bfDefault; {$IFDEF OGL_USE_ENUMS}FloatType: TVertexAttribPointerType.{$ELSE}DataType: {$ENDIF}GL_FLOAT;)
        );
      );
    RawV4fT2fC4f : record
      Header: TDynArrayRec;
      Arr: array [0..2] of TVBOElementFormat;
    end = (Header: (RefCnt: -1; Length: 3); Arr: (
        (Normalized: False; Size: 4; Stride: (4 + 2 + 4) * SizeOf(GLfloat); Offset: 0; BindFunction: bfDefault; {$IFDEF OGL_USE_ENUMS}FloatType: TVertexAttribPointerType.{$ELSE}DataType: {$ENDIF}GL_FLOAT;),
        (Normalized: False; Size: 2; Stride: (4 + 2 + 4) * SizeOf(GLfloat); Offset: 4 * SizeOf(GLfloat); BindFunction: bfDefault; {$IFDEF OGL_USE_ENUMS}FloatType: TVertexAttribPointerType.{$ELSE}DataType: {$ENDIF}GL_FLOAT;),
        (Normalized: False; Size: 4; Stride: (4 + 2 + 4) * SizeOf(GLfloat); Offset: (4 + 2) * SizeOf(GLfloat); BindFunction: bfDefault; {$IFDEF OGL_USE_ENUMS}FloatType: TVertexAttribPointerType.{$ELSE}DataType: {$ENDIF}GL_FLOAT;)
        );
      );
    RawV4fT3fC4f : record
      Header: TDynArrayRec;
      Arr: array [0..2] of TVBOElementFormat;
    end = (Header: (RefCnt: -1; Length: 3); Arr: (
        (Normalized: False; Size: 4; Stride: (4 + 3 + 4) * SizeOf(GLfloat); Offset: 0; BindFunction: bfDefault; {$IFDEF OGL_USE_ENUMS}FloatType: TVertexAttribPointerType.{$ELSE}DataType: {$ENDIF}GL_FLOAT;),
        (Normalized: False; Size: 3; Stride: (4 + 3 + 4) * SizeOf(GLfloat); Offset: 4 * SizeOf(GLfloat); BindFunction: bfDefault; {$IFDEF OGL_USE_ENUMS}FloatType: TVertexAttribPointerType.{$ELSE}DataType: {$ENDIF}GL_FLOAT;),
        (Normalized: False; Size: 4; Stride: (4 + 3 + 4) * SizeOf(GLfloat); Offset: (4 + 3) * SizeOf(GLfloat); BindFunction: bfDefault; {$IFDEF OGL_USE_ENUMS}FloatType: TVertexAttribPointerType.{$ELSE}DataType: {$ENDIF}GL_FLOAT;)
        );
      );

var
  LogOut: TOGLLogFunctionObj = nil;

function SetLogFunction(ALogFunction: TOGLLogFunction; ASelf: Pointer): TOGLLogFunctionObj;
var m: TMethod;
begin
  m.Code:= Addr(ALogFunction);
  m.Data:= ASelf;
  Result:= SetLogFunction(TOGLLogFunctionObj(m));
end;

function SetLogFunction(ALogFunction: TOGLLogFunctionObj): TOGLLogFunctionObj;
begin
  Result:= LogOut;
  LogOut:= ALogFunction;
end;

procedure LogOutput(AClass: TClass; const AFunctionName, AMessage: string);
begin
  if Assigned(LogOut) then
    LogOut(AClass, AFunctionName, AMessage);
end;

procedure DebugLogOutputAllErrors(AClass: TClass; const AFunctionName: string);
begin
  {$IFDEF DEBUG}
  LogOutputAllErrors(AClass, AFunctionName);
  {$ENDIF}
end;

procedure LogOutputAllErrors(AClass: TClass; const AFunctionName: string);
var err: GLenum;
begin
  if Assigned(LogOut) then begin
    err:= glGetError;
    while err <> GL_NO_ERROR do begin
      LogOut(AClass, AFunctionName, Format('OpenGL Error: %d', [err]));
      err:= glGetError;
    end;
  end;
end;

function GetShaderLog(Shader: GLuint): string;
var s: AnsiString;
begin
  GetShaderLog(Shader, s);
  Result:= string(s);
end;

procedure GetShaderLog(Shader: GLuint; out Result: AnsiString);
var maxLength: Integer;
begin
  glGetShaderiv(Shader, {$IFDEF OGL_USE_ENUMS}TShaderParameterName.{$ENDIF}GL_INFO_LOG_LENGTH, @maxLength);
  SetLength(Result, maxLength);
	glGetShaderInfoLog(Shader, maxLength, maxLength, Pointer(Result));
  SetLength(Result, maxLength);
end;

function GetProgramLog(_Program: GLuint): string;
var s: AnsiString;
begin
  GetProgramLog(_Program, s);
  Result:= string(s);
end;

procedure SetViewPortSize(Width, Height: GLint);
begin
  GlobalViewPortSize[0]:= Width;
  GlobalViewPortSize[1]:= -Height;
  GlobalViewPortSizeInteger[0]:= Width;
  GlobalViewPortSizeInteger[1]:= Height;
end;

procedure GetProgramLog(_Program: GLuint; out Result: AnsiString);
var maxLength: Integer;
begin
  glGetProgramiv(_Program, {$IFDEF OGL_USE_ENUMS}TProgramPropertyARB.{$ENDIF}GL_INFO_LOG_LENGTH, @maxLength);
  SetLength(Result, maxLength);
	glGetProgramInfoLog(_Program, maxLength, maxLength, Pointer(Result));
  SetLength(Result, maxLength);
end;

procedure RaiseOpenGLError;
begin
  RaiseOpenGLError(glGetError, '');
end;

procedure RaiseOpenGLError(LastError: Integer);
begin
  RaiseOpenGLError(LastError, '');
end;

procedure RaiseOpenGLError(LastError: Integer; const AdditionalInfo: string);
var
  Error: EOSError;
begin
  //if LastError <> 0 then
    Error := EOSError.CreateResFmt(@SOGLError, [LastError, {SysErrorMessage(LastError),} AdditionalInfo]);
  {else
    Error := EOSError.CreateRes(@SUnkOSError); }
  Error.ErrorCode := LastError;
  raise Error;
end;

procedure SetDCPixelFormat(DC : HDC; var PF: TPixelFormatDescriptor);
var nPixelFormat : Integer;
begin
  nPixelFormat := ChoosePixelFormat (DC, @PF);
  if nPixelFormat = 0 then
    RaiseLastOSError;
  if not SetPixelFormat (DC, nPixelFormat, @PF) then
    RaiseLastOSError;
  if not DescribePixelFormat(DC, nPixelFormat, SizeOf(PF), PF) then
    RaiseLastOSError;
end;

function CreateShader(_Type: {$IFDEF OGL_USE_ENUMS}TShaderType{$ELSE}GLenum{$ENDIF}; Res: PAnsiChar): GLuint;
begin
  Result:= CreateShader(_Type, [Res]);
end;

function CreateShader(_Type: {$IFDEF OGL_USE_ENUMS}TShaderType{$ELSE}GLenum{$ENDIF}; Res: array of PAnsiChar): GLuint;
begin
  Result:= glCreateShader(_Type);
  if Result = 0 then
    RaiseOpenGLError;
  glShaderSource(Result, Length(Res), @Res[0], nil);
  glCompileShader(Result);
end;

function CreateOpenGL30Context(Handle: THandle; var GL: TGLContext): Integer;
const attributes : array [0..6] of LongWord =
        (
          WGL_CONTEXT_MAJOR_VERSION_ARB, 3,
          WGL_CONTEXT_MINOR_VERSION_ARB, 0,
          WGL_CONTEXT_FLAGS_ARB,         WGL_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB,
          0
        );
var tempRC: HGLRC;
    DC: HDC;
begin
  DC := GetDC(Handle);

  try
    SetDCPixelFormat(DC, GL.PF);
    tempRC := wglCreateContext(DC);
    if tempRC = 0 then
      RaiseLastOSError(GetLastError, 'Creating temporary render context fail.');
    if not wglMakeCurrent(DC, tempRC) then
      RaiseLastOSError(GetLastError, 'Selecting temporary render context fail.');

    InitializeWGL_ARB_create_context;
    if Addr(wglCreateContextAttribsARB) = nil then
      raise ENotImplemented.Create('Load wglCreateContextAttribsARB fail.');

    GL.GLRC:= wglCreateContextAttribsARB(DC, 0, @attributes);
    if GL.GLRC = 0 then
      RaiseLastOSError(GetLastError, 'Creating render context fail.');

    if not wglMakeCurrent(DC, GL.GLRC) then begin
      wglDeleteContext(GL.GLRC);
      GL.GLRC:= 0;
      RaiseLastOSError(GetLastError, 'Selecting render context fail.');
    end;

  finally
    wglDeleteContext(tempRC);
    ReleaseDC(Handle, DC);
  end;
end;

{procedure CreateCylinder(x, y, z, AngleX, AngleY, AngleZ, bR, tR, H: GLfloat;
  Slices, Stacks: Integer; n, tc, v: TList<Single>; ind: TList<LongInt>; Grad: Single);
var
  vec: array [0..9] of GLfloat;
  norm, tex: array [0..2] of GLfloat;
  i, j, k: Integer;
  rad: array [0..1] of double;
  R: GLfloat;
begin
  if (v = nil) or (ind = nil) then Exit;
  R:= (tR - bR) / Stacks;
  for i:=0 to Slices - 1 do begin
    rad[0]:= DegToRad(Grad) / Slices * i;
    rad[1]:= DegToRad(Grad) / Slices * (i + 1);
    vec[1]:= cos(rad[0]) * bR;
    vec[2]:= sin(rad[0]) * bR;
    vec[3]:= cos(rad[1]) * tR;
    vec[4]:= sin(rad[1]) * tR;
    vec[6]:= cos(rad[0]) * tR;
    vec[7]:= sin(rad[0]) * tR;
    CalcNormal(norm[0], norm[1], norm[2], 0, vec[1], vec[2],
      H / Stacks, vec[3], vec[4], H / Stacks, vec[6], vec[7]);
    Rotate(norm[0], norm[1], norm[2], AngleX, AngleY, AngleZ);
    for j:=0 to Stacks - 1 do begin
      vec[0]:= j * H / Stacks;
      vec[1]:= cos(rad[0]) * (bR + R * j);
      vec[2]:= sin(rad[0]) * (bR + R * j);
      vec[3]:= cos(rad[1]) * (bR + R * j);
      vec[4]:= sin(rad[1]) * (bR + R * j);
      vec[5]:= (j + 1) * H / Stacks;
      vec[6]:= cos(rad[0]) * (bR + R * (j + 1));
      vec[7]:= sin(rad[0]) * (bR + R * (j + 1));
      vec[8]:= cos(rad[1]) * (bR + R * (j + 1));
      vec[9]:= sin(rad[1]) * (bR + R * (j + 1));
      if j = 0 then begin
        tex[0]:= vec[0];
        tex[1]:= vec[1];
        tex[2]:= vec[2];
        Translate(tex[0], tex[1], tex[2], x, y, z);
        Rotate(tex[0], tex[1], tex[2], AngleX, AngleY, AngleZ);
        v.Add(tex[0]);
        v.Add(tex[1]);
        v.Add(tex[2]);
        ind.Add((v.Count div 3) - 1);
        tex[0]:= vec[0];
        tex[1]:= vec[3];
        tex[2]:= vec[4];
        Translate(tex[0], tex[1], tex[2], x, y, z);
        Rotate(tex[0], tex[1], tex[2], AngleX, AngleY, AngleZ);
        v.Add(tex[0]);
        v.Add(tex[1]);
        v.Add(tex[2]);
        ind.Add((v.Count div 3) - 1);
        for k:=0 to 5 do
          n.Add(norm[k mod 3]);
      end else begin
        ind.Add(ind[ind.Count - 1]);
        ind.Add(ind[ind.Count - 3]);
      end;
      tex[0]:= vec[5];
      tex[1]:= vec[8];
      tex[2]:= vec[9];
      Translate(tex[0], tex[1], tex[2], x, y, z);
      Rotate(tex[0], tex[1], tex[2], AngleX, AngleY, AngleZ);
      v.Add(tex[0]);
      v.Add(tex[1]);
      v.Add(tex[2]);
      ind.Add((v.Count div 3) - 1);
      ind.Add(ind[ind.Count - 3]);
      ind.Add(ind[ind.Count - 2]);
      tex[0]:= vec[5];
      tex[1]:= vec[6];
      tex[2]:= vec[7];
      Translate(tex[0], tex[1], tex[2], x, y, z);
      Rotate(tex[0], tex[1], tex[2], AngleX, AngleY, AngleZ);
      v.Add(tex[0]);
      v.Add(tex[1]);
      v.Add(tex[2]);
      ind.Add((v.Count div 3) - 1);
      for k:=0 to 5 do
        n.Add(norm[k mod 3]);
    end;
  end;
end;

procedure CalcNormal(var nx, ny, nz: GLfloat; x1, y1, z1, x2, y2, z2,
  x3, y3, z3: GLfloat);
var vx1,vy1,vz1,vx2,vy2,vz2: GLfloat;
begin
  //приращение координат вешин по осям
  vx1:=x1-x2;
  vy1:=y1-y2;
  vz1:=z1-z2;

  vx2:=x2-x3;
  vy2:=y2-y3;
  vz2:=z2-z3;

  // вектор-перпендикуляр к центру треугольника
  nx:=vy1*vz2- vz1*vy2;
  ny:=vz1*vx2- vx1*vz2;
  nz:=vx1*vy2- vy1*vx2;

  //получаем унитарный вектор единичной длины
  Normalize(nx, ny, nz);
end;

procedure Translate(var x, y, z: GLfloat; dx, dy, dz: GLfloat);
begin
  x:= x + dx;
  y:= y + dy;
  z:= z + dz;
end;

procedure Rotate(var x, y, z: GLfloat; ax, ay, az: GLfloat);
var Rot: TQuaternion;
begin
  Rot.SetValue(1, 0, 0, DegToRad(ax));
  Rot.MultVec(x, y, z);
  Rot.SetValue(0, 1, 0, DegToRad(ay));
  Rot.MultVec(x, y, z);
  Rot.SetValue(0, 0, 1, DegToRad(az));
  Rot.MultVec(x, y, z);
end;

procedure Normalize(var nx, ny, nz: GLFloat);
var t: GLfloat;
begin
  t:= sqrt(nx * nx + ny * ny + nz * nz);
  if (t > VA_EPSILON) then begin
    nx:=nx/t;
    ny:=ny/t;
    nz:=nz/t;
  end;
end;}

{TFloatCamera}

constructor TFloatCamera.Create;
begin

end;

function TFloatCamera.GetGA: Single;
begin
  Result:= 180 + prAzimuth + FRotZ;
end;

procedure TFloatCamera.SetAzimuth(Angle: Single);
begin
  prAzimuth:= Angle;
  if prAzimuth > maxAzimuth then
    prAzimuth:= maxAzimuth;
  if prAzimuth < minAzimuth then
    prAzimuth:= minAzimuth;
end;

procedure TFloatCamera.SetGA(Angle: Single);
begin
  Azimuth:= Angle - 180 - FRotZ;
end;

procedure TFloatCamera.SetRotZ(Angle: Single);
begin
  Azimuth:= prAzimuth + FRotZ - Angle;
  FRotZ:= Angle;
end;

{ TVBOBuffer }

procedure TVertexBufferObject.Bind;
begin
  _Indices.Bind;
  _Elements.Bind;
end;

constructor TVertexBufferObject.Create(const AElementsFormat: TArray<TVBOElementFormat>;
  AIndeces, AElements: GLuint; AIndecesType: {$IFDEF OGL_USE_ENUMS}TDrawElementsType{$ELSE}GLenum{$ENDIF}; AIndecesCount, AIndecesStride: GLsizei; AIsQuads: Boolean);
begin
  _Indices.Create(AIndeces, AIndecesType, AIndecesCount, AIndecesStride);
  _Elements.Create(AElementsFormat, AElements);
  _IsQuads:= AIsQuads;
end;

procedure TVertexBufferObject.Draw(const AttribIndicies: array of GLuint);
begin
  if _IsQuads then
    Draw(0, _Indices._IndicesCount div 3 * 2, 0, _Indices._IndicesCount, AttribIndicies)
  else
    Draw(0, _Indices._IndicesCount, 0, _Indices._IndicesCount, AttribIndicies)
end;

constructor TVertexBufferObject.CreateQuadsSurface(const AVector: array of GLfloat);
begin

end;

procedure TVertexBufferObject.FreeContext;
begin
  _Elements.FreeContext;
  _Indices.FreeContext;
end;

constructor TVertexBufferObject.New(
  const AElementsFormat: TArray<TVBOElementFormat>; AIndecesType: {$IFDEF OGL_USE_ENUMS}TDrawElementsType{$ELSE}GLenum{$ENDIF};
  AIndecesCount, AIndecesStride: GLsizei; AIsQuads: Boolean);
var b: array [0..1] of GLuint;
begin
  FreeContext;
  glGenBuffers(2, @b);
  _Indices.Create(b[0], AIndecesType, AIndecesCount, AIndecesStride);
  _Elements.Create(AElementsFormat, b[1]);
  _IsQuads:= AIsQuads;
end;

procedure TVertexBufferObject.Draw(BeginIndex, EndIndex, IndecesOffset, IndecesCount: GLsizei;
  const AttribIndicies: array of GLuint);
begin
  _Indices.Bind;
  _Elements.Bind;
  _Elements.EnableAttributes(AttribIndicies);

  _Indices.Draw({$IFDEF OGL_USE_ENUMS}TPrimitiveType.{$ENDIF}GL_TRIANGLES,
      BeginIndex, EndIndex, IndecesOffset, IndecesCount);

  _Elements.Disable(AttribIndicies);

  glBindBuffer({$IFDEF OGL_USE_ENUMS}TBufferTargetARB.{$ENDIF}GL_ELEMENT_ARRAY_BUFFER, 0);
  glBindBuffer({$IFDEF OGL_USE_ENUMS}TBufferTargetARB.{$ENDIF}GL_ARRAY_BUFFER, 0);
end;

function TVertexBufferObject.ElementFormatsCount: Integer;
begin
  Result:= Length(_Elements._ElementsFormat);
end;

{ TBitmapFont }

constructor TBitmapFont.Create(const AFontName: string; AHeight: Integer; const ADefaultCharAndStartLayers: string);
var f: TFontData;
begin
  f.Create(AFontName, AHeight, [], TFontQuality.fqClearType);
  Create(f, ADefaultCharAndStartLayers);
end;

procedure TBitmapFont.GenerateTextDIP(const Prepared: TPreparedText;
  var DIP: TDIP; AOffset: TPoint; AColor: TColor; AOpasity, AScale: GLfloat);
var
    FloatUniforms: TArray<TUniformValue<GLfloat>>;
    IntUniforms: TArray<TUniformValue<GLint>>;
    EndVertexIndex, IndexCount: GLsizei;
begin
  EndVertexIndex:= (Prepared.SymbolsCount * 4) - 1;
  IndexCount:= Prepared.SymbolsCount * 6;

  SetLength(IntUniforms, 1);
  IntUniforms[0].Info:= FTextureUniform;
  SetLength(IntUniforms[0].Value, IntUniforms[0].Info.Size);
  IntUniforms[0].Value[0]:= 0; //GL_TEXTURE0

  SetLength(FloatUniforms, 3);
  FloatUniforms[0].Info:= FScreenSizeUniform;
  GetViewPortSize(FloatUniforms[0].Value);

  FloatUniforms[1].Info:= FTextOffsetUniform;
  SetLength(FloatUniforms[1].Value, FloatUniforms[1].Info.Size);
  FloatUniforms[1].Value[0]:= AOffset.X;
  FloatUniforms[1].Value[1]:= FloatUniforms[0].Value[1] - AOffset.Y;
  FloatUniforms[1].Value[2]:= AScale;

  FloatUniforms[2].Info:= FColorUniform;
  SetLength(FloatUniforms[2].Value, FloatUniforms[2].Info.Size);
  FloatUniforms[2].Value[0]:= LongRec(AColor).Bytes[0] / 256;
  FloatUniforms[2].Value[1]:= LongRec(AColor).Bytes[1] / 256;
  FloatUniforms[2].Value[2]:= LongRec(AColor).Bytes[2] / 256;
  FloatUniforms[2].Value[3]:= AOpasity;

  DIP.Create(Prepared.Buffer, TShaderBlock.Create(FProgramFontOC._Program, IntUniforms, FloatUniforms, nil),
    FTextures, [MeshCoord, TexCoord], 0, EndVertexIndex, 0, IndexCount);
end;

function TBitmapFont.GetTextHeight(const AText: string): Integer;
begin

end;

function TBitmapFont.GetTextRect(const AText: string): TRect;
begin

end;

function TBitmapFont.GetTextSize(const AText: string): TSize;
begin

end;

function TBitmapFont.GetTextWidth(const AText: string): Integer;
begin

end;

class procedure TBitmapFont.InitializeProgram;
var link: Integer;
    p: GLuint;
begin
  p:= glCreateProgram;
  if p = 0 then
    RaiseOpenGLError;

  FProgramFontOC.Create(p, [CreateShader({$IFDEF OGL_USE_ENUMS}TShaderType.{$ENDIF}GL_FRAGMENT_SHADER, TFFS_Color),
      CreateShader({$IFDEF OGL_USE_ENUMS}TShaderType.{$ENDIF}GL_VERTEX_SHADER, TFVS_OfsColor)]);

  FProgramFontOC.AttachAll;
  glBindAttribLocation(FProgramFontOC._Program, MeshCoord, 'Mesh');
  glBindAttribLocation(FProgramFontOC._Program, TexCoord, 'TexCoord');
  LogOutput(TBitmapFont, 'InitializeProgram FragmetShader', GetShaderLog(FProgramFontOC._Shaders[0]));
  LogOutput(TBitmapFont, 'InitializeProgram VertexShader', GetShaderLog(FProgramFontOC._Shaders[1]));
  glLinkProgram(FProgramFontOC._Program);
  glGetProgramiv(FProgramFontOC._Program, {$IFDEF OGL_USE_ENUMS}TProgramPropertyARB.{$ENDIF}GL_LINK_STATUS, @link);
  if link = 0 then
    RaiseOpenGLError(0, GetProgramLog(FProgramFontOC._Program));
  FScreenSizeUniform.Index:= glGetUniformLocation(FProgramFontOC._Program, 'Screen');
  FScreenSizeUniform.Size:= Length(GlobalViewPortSize);
  FColorUniform.Index:= glGetUniformLocation(FProgramFontOC._Program, 'Color');
  FColorUniform.Size:= 4;
  FTextureUniform.Index:= glGetUniformLocation(FProgramFontOC._Program, 'Map');
  FTextureUniform.Size:= 1;
  FTextOffsetUniform.Index:= glGetUniformLocation(FProgramFontOC._Program, 'Offsets');
  FTextOffsetUniform.Size:= 3;
  LogOutput(TBitmapFont, 'InitializeProgram ProgramFont', GetProgramLog(FProgramFontOC._Program));
end;

function TBitmapFont.PrepareText(const AText: string; out Prepared: TPreparedText): Boolean;
var P: array [0..3] of TElementV2T2<GLfloat>;
    //I: ^Ind;
    I: array [0..5] of Word;
    j, xOfs, C, L, fix: Integer;
    ps: PChar;
    v: array [0..1] of GLuint;
    SpaceWidth, MW: Integer;
    pb, def: PBitmapCharBlock;
    Cur: UCS4Char;
    last: Cardinal;
begin
  Result:= True;
  if AText = '' then Exit;
  ActualizeState;
  def:= GetCharInfo(DefaultChar);
  if def = nil then
    Exit(False);
  last:= Cardinal(-1);
  Prepared.MaxWidth:= 0;
  MW:= 0;
  ps:= Pointer(AText);
  C:= 0;
  L:= 1;
  while ps^ <> #0 do begin
    case Ord(ps^) of
      Ord(' '):;
      {$IFNDEF USE10AS13}
      10: ;
      {$ENDIF}
      13 {$IFDEF USE10AS13}, 10{$ENDIF}: Inc(L);
    else
      if IsFirstSurrogateChar(ps^) then
        Inc(ps);
      Inc(C);
    end;
    Inc(ps);
  end;
  //GetMem(I, C * 6 * 2);
  glGenBuffers(2, @v[0]);
  Prepared.Buffer.Create(TVBOElementFormats.ElementFormatV2fT2f, v[0], v[1], {$IFDEF OGL_USE_ENUMS}TDrawElementsType.{$ENDIF}GL_UNSIGNED_SHORT, C * 6, SizeOf(Word), True);
  Prepared.SymbolsCount:= C;
  SetLength(Prepared.LineEndSymbolIndex, L - 1);
  L:= 0;
  ps:= Pointer(AText);
  xOfs:= 0;
  Prepared.Buffer._Indices.Bind;
  Prepared.Buffer._Elements.Bind;
  glBufferData({$IFDEF OGL_USE_ENUMS}TBufferTargetARB.{$ENDIF}GL_ARRAY_BUFFER, C * SizeOf(P), nil, {$IFDEF OGL_USE_ENUMS}TBufferUsageARB.{$ENDIF}GL_STATIC_DRAW);
  glBufferData({$IFDEF OGL_USE_ENUMS}TBufferTargetARB.{$ENDIF}GL_ELEMENT_ARRAY_BUFFER, C * SizeOf(I), nil, {$IFDEF OGL_USE_ENUMS}TBufferUsageARB.{$ENDIF}GL_STATIC_DRAW);
  P[0].Vector[1]:= 0;
  P[1].Vector[1]:= 0;
  P[2].Vector[1]:= - Height;
  P[3].Vector[1]:= - Height;
  I[0]:= 0; I[1]:= 1; I[2]:= 2;
  I[3]:= 0; I[4]:= 2; I[5]:= 3;
  pb:= GetCharInfo(Ord(' '));
  if pb <> nil then
    SpaceWidth:= pb.Width[Ord(' ')]
  else
    SpaceWidth:= def.Width[Ord(DefaultChar) and $FF];

  for j:= 0 to C - 1 do begin
    while True do begin
      case Ord(ps^) of
        Ord(' '): Inc(xOfs, SpaceWidth);
        {$IFNDEF USE10AS13}
        10: xOfs:= 0;
        {$ENDIF}
        13 {$IFDEF USE10AS13}, 10{$ENDIF}: begin
          P[0].Vector[1]:= P[0].Vector[1] - Height;
          P[1].Vector[1]:= P[1].Vector[1] - Height;
          P[2].Vector[1]:= P[2].Vector[1] - Height;
          P[3].Vector[1]:= P[3].Vector[1] - Height;
          Prepared.LineEndSymbolIndex[L]:= j;
          Inc(L);
        end;
      else
        Break;
      end;
      Inc(ps);
    end;
    Cur:= SurrogateToUCS4Char(ps);
    if IsFirstSurrogateChar(ps^) then
      Inc(ps);
    Inc(ps);
    pb:= GetCharInfo(Cur);
    if pb = nil then begin
      if last <> Cur shr 8 then begin
        last:= Cur shr 8;
        AddNewLayer(last);
      end;
      pb:= def;
      Cur:= DefaultChar;
      Result:= False;
    end;
    P[1].Vector[0]:= pb.ABC[Cur and $FF].abcA + xOfs - 1;
    P[2].Vector[0]:= pb.ABC[Cur and $FF].abcA + xOfs - 1;
    fix:= pb.ABC[Cur and $FF].abcB + 1;//Max(pb.ABC[Cur and $FF].abcB, pb.Width[Cur and $FF]);
    P[0].Vector[0]:= fix + pb.ABC[Cur and $FF].abcA + xOfs;
    P[3].Vector[0]:= fix + pb.ABC[Cur and $FF].abcA + xOfs;
    P[0].TexCoord:= pb.TexCoord[Cur and $FF, 0];
    P[1].TexCoord:= pb.TexCoord[Cur and $FF, 1];
    P[2].TexCoord:= pb.TexCoord[Cur and $FF, 2];
    P[3].TexCoord:= pb.TexCoord[Cur and $FF, 3];
    Inc(xOfs, pb.Width[Cur and $FF]);
    if xOfs > MW then
      MW:= xOfs;
    glBufferSubData({$IFDEF OGL_USE_ENUMS}TBufferTargetARB.{$ENDIF}GL_ARRAY_BUFFER, j * SizeOf(P), SizeOf(P){4 * 2 * 4 * 2}, @P);
    glBufferSubData({$IFDEF OGL_USE_ENUMS}TBufferTargetARB.{$ENDIF}GL_ELEMENT_ARRAY_BUFFER, j * SizeOf(I), SizeOf(I){6 * 2}, @I[0]);
    Inc(I[0], 4); Inc(I[1], 4); Inc(I[2], 4);
    Inc(I[3], 4); Inc(I[4], 4); Inc(I[5], 4);
  end;
  Prepared.MaxWidth:= MW;
end;

function TBitmapFont.PrepareTextRect(const AText: string;
  const ABoundRect: TRect; const AOffset: TPoint; out APrepared: TBorderedText;
  AColor: TColor; AScale: GLfloat; AWordWrap: Boolean): Boolean;
begin
  Result:= True;
  if AText = '' then Exit;
  if AWordWrap then
    Result:= PrepareTextWordWrap(AText, ABoundRect.Right - AOffset.X + ABoundRect.Left, taLeft, APrepared.Prepared)
  else
    Result:= PrepareText(AText, APrepared.Prepared);

  APrepared.BoundRect:= ABoundRect;

  UpdateTextOffset(APrepared, AOffset, AColor, AScale);
end;

procedure TBitmapFont.PrepareTextWordWrap(const AText: string;
  const AInfo: TTextInfo; Default: PBitmapCharBlock; SpaceWidth: Integer;
  var Prepared: TPreparedText);
var P: array [0..3] of TElementV2T2<GLfloat>;
    I: array [0..5] of Word;
    j, k, xOfs, L: Integer;
    ps: PChar;
    v: array [0..1] of GLuint;
    pb: PBitmapCharBlock;
    Cur: UCS4Char;
    last: Cardinal;
begin
  glGenBuffers(2, @v[0]);
  Prepared.Buffer.Create(TVBOElementFormats.ElementFormatV2fT2f, v[0], v[1], {$IFDEF OGL_USE_ENUMS}TDrawElementsType.{$ENDIF}GL_UNSIGNED_SHORT, AInfo.SymbolsCount * 6, SizeOf(Word), True);
  Prepared.SymbolsCount:= AInfo.SymbolsCount;
  Prepared.LineEndSymbolIndex:= AInfo.LineEndSymbolIndex;
  ps:= Pointer(AText);
  Prepared.Buffer._Indices.Bind;
  Prepared.Buffer._Elements.Bind;
  glBufferData({$IFDEF OGL_USE_ENUMS}TBufferTargetARB.{$ENDIF}GL_ARRAY_BUFFER, AInfo.SymbolsCount * SizeOf(P), nil, {$IFDEF OGL_USE_ENUMS}TBufferUsageARB.{$ENDIF}GL_STATIC_DRAW);
  glBufferData({$IFDEF OGL_USE_ENUMS}TBufferTargetARB.{$ENDIF}GL_ELEMENT_ARRAY_BUFFER, AInfo.SymbolsCount * SizeOf(I), nil, {$IFDEF OGL_USE_ENUMS}TBufferUsageARB.{$ENDIF}GL_STATIC_DRAW);
  P[0].Vector[1]:= 0;
  P[1].Vector[1]:= 0;
  P[2].Vector[1]:= - Height;
  P[3].Vector[1]:= - Height;
  I[0]:= 0; I[1]:= 1; I[2]:= 2;
  I[3]:= 0; I[4]:= 2; I[5]:= 3;

  L:= 0;
  last:= $FFFFFFFF;
  for k:= 0 to High(Prepared.LineEndSymbolIndex) do begin
    xOfs:= AInfo.LinesAlignment[k].OffsetX;
    while True do begin
      case Ord(ps^) of
        Ord(' '), 13, 10: ; //пробелы, возвраты каретки и переводы строк в конце линии обрезаются, т.к. уже учтены в выравнивании
      else
        Break;
      end;
      Inc(ps);
    end;
    for j:= L to Prepared.LineEndSymbolIndex[k] - 1 do begin
      Cur:= SurrogateToUCS4Char(ps);
      if IsFirstSurrogateChar(ps^) then
        Inc(ps);
      Inc(ps);
      pb:= GetCharInfo(Cur);
      if pb = nil then begin
        if last <> Cur shr 8 then begin
          last:= Cur shr 8;
          AddNewLayer(last);
        end;
        pb:= Default;
        Cur:= DefaultChar;
      end;
      P[1].Vector[0]:= pb.ABC[Cur and $FF].abcA + xOfs - 1;
      P[2].Vector[0]:= P[1].Vector[0];
      P[0].Vector[0]:= pb.ABC[Cur and $FF].abcB + 1 + pb.ABC[Cur and $FF].abcA + xOfs;
      P[3].Vector[0]:= P[0].Vector[0];
      P[0].TexCoord:= pb.TexCoord[Cur and $FF, 0];
      P[1].TexCoord:= pb.TexCoord[Cur and $FF, 1];
      P[2].TexCoord:= pb.TexCoord[Cur and $FF, 2];
      P[3].TexCoord:= pb.TexCoord[Cur and $FF, 3];
      Inc(xOfs, pb.Width[Cur and $FF]);
      glBufferSubData({$IFDEF OGL_USE_ENUMS}TBufferTargetARB.{$ENDIF}GL_ARRAY_BUFFER, j * SizeOf(P), SizeOf(P), @P);
      glBufferSubData({$IFDEF OGL_USE_ENUMS}TBufferTargetARB.{$ENDIF}GL_ELEMENT_ARRAY_BUFFER, j * SizeOf(I), SizeOf(I), @I[0]);
      Inc(I[0], 4); Inc(I[1], 4); Inc(I[2], 4);
      Inc(I[3], 4); Inc(I[4], 4); Inc(I[5], 4);
      while True do begin
        case Ord(ps^) of
          Ord(' '): Inc(xOfs, AInfo.LinesAlignment[k].SpaceWidth);
          {$IFNDEF USE10AS13}
          10: xOfs:= 0;
          {$ENDIF}
          13 {$IFDEF USE10AS13}, 10{$ENDIF}: ; //по идее не должны попадаться, т.к. уже учтены при выравнивании
        else
          Break;
        end;
        Inc(ps);
      end;
    end;
    L:= Prepared.LineEndSymbolIndex[k];
    P[0].Vector[1]:= P[0].Vector[1] - Height;
    P[1].Vector[1]:= P[1].Vector[1] - Height;
    P[2].Vector[1]:= P[2].Vector[1] - Height;
    P[3].Vector[1]:= P[3].Vector[1] - Height;
  end;
end;

function TBitmapFont.PrepareTextWordWrap(const AText: string; MaxWidth: Integer;
  Align: TTextAlign; out Prepared: TPreparedText): Boolean;
var SpaceWidth: Integer;
    pb, def: PBitmapCharBlock;
    info: TTextInfo;
begin
  Result:= True;
  if AText = '' then Exit;
  ActualizeState;
  def:= GetCharInfo(DefaultChar);
  if def = nil then
    Exit(False);
  pb:= GetCharInfo(Ord(' '));
  if pb <> nil then
    SpaceWidth:= pb.Width[Ord(' ')]
  else
    SpaceWidth:= def.Width[Ord(DefaultChar) and $FF];

  Result:= GetTextInfo(AText, info, def.Width[Ord(DefaultChar) and $FF], SpaceWidth, MaxWidth, Align, True);

  PrepareTextWordWrap(AText, info, def, SpaceWidth, Prepared);
end;

procedure TBitmapFont.UpdateTextOffset(var APrepared: TBorderedText;
  const AOffset: TPoint; AColor: TColor; AOpasity, AScale: GLfloat);
var
    FloatUniforms: TArray<TUniformValue<GLfloat>>;
    IntUniforms: TArray<TUniformValue<GLint>>;
    BeginVertexIndex, EndVertexIndex, IndexOffset, IndexCount: GLsizei;
    line: Integer;
begin
  BeginVertexIndex:= 0;
  IndexOffset:= 0;

  line:= (APrepared.BoundRect.Top - AOffset.Y) div LineHeight;
  if line > 0 then begin
    IndexOffset:= APrepared.Prepared.LineEndSymbolIndex[line - 1];
    BeginVertexIndex:= IndexOffset * 4 + 1;
  end;

  line:= (APrepared.BoundRect.Bottom - AOffset.Y) div LineHeight;
  if (line >=0) and (line < Length(APrepared.Prepared.LineEndSymbolIndex)) then begin
    EndVertexIndex:= APrepared.Prepared.LineEndSymbolIndex[line] * 4 - 1;
    IndexCount:= (APrepared.Prepared.LineEndSymbolIndex[line] - IndexOffset) * 6;
  end else begin
    EndVertexIndex:= (APrepared.Prepared.SymbolsCount * 4) - 1;
    IndexCount:= (APrepared.Prepared.SymbolsCount - IndexOffset) * 6;
  end;
  IndexOffset:= IndexOffset * 6;

  SetLength(IntUniforms, 1);
  IntUniforms[0].Info:= FTextureUniform;
  SetLength(IntUniforms[0].Value, IntUniforms[0].Info.Size);
  IntUniforms[0].Value[0]:= 0; //GL_TEXTURE0

  SetLength(FloatUniforms, 3);
  FloatUniforms[0].Info:= FScreenSizeUniform;
  GetViewPortSize(FloatUniforms[0].Value);

  FloatUniforms[1].Info:= FTextOffsetUniform;
  SetLength(FloatUniforms[1].Value, FloatUniforms[1].Info.Size);
  FloatUniforms[1].Value[0]:= AOffset.X;
  FloatUniforms[1].Value[1]:= GlobalViewPortSize[1] - AOffset.Y;
  FloatUniforms[1].Value[2]:= AScale;

  FloatUniforms[2].Info:= FColorUniform;
  SetLength(FloatUniforms[2].Value, FloatUniforms[2].Info.Size);
  FloatUniforms[2].Value[0]:= LongRec(AColor).Bytes[0] / 255;
  FloatUniforms[2].Value[1]:= LongRec(AColor).Bytes[1] / 255;
  FloatUniforms[2].Value[2]:= LongRec(AColor).Bytes[2] / 255;
  FloatUniforms[2].Value[3]:= AOpasity;

  APrepared.ReadyToDraw.Create(APrepared.Prepared.Buffer, TShaderBlock.Create(FProgramFontOC._Program, IntUniforms, FloatUniforms, nil),
    FTextures, [MeshCoord, TexCoord], BeginVertexIndex, EndVertexIndex, IndexOffset, IndexCount);
end;

{ TGLRenderer }

constructor TGLRenderer.Create;
begin

end;

destructor TGLRenderer.Destroy;
begin

end;

procedure TGLRenderer.Initialize;
begin

end;

procedure TGLRenderer.Reset;
begin

end;

{ TBitmapFontData }

procedure TBitmapFontData.Clear;
var
  i: Integer;
begin
  for i := 0 to High(CharTable) do
    if CharTable[i] <> nil then begin
      Dispose(CharTable[i]);
    end;
end;

{ TShaderBlock }

constructor TShaderBlock.Create(AProgram: GLuint;
  const AIntegerUniforms: TArray<TUniformValue<GLint>>;
  const AFloatUniforms: TArray<TUniformValue<GLfloat>>;
  const AMatrixUniforms: TArray<TUniformMatrixValue>);
begin
  _Program:= AProgram;
  _IntegerUniforms:= AIntegerUniforms;
  _FloatUniforms:= AFloatUniforms;
  _MatrixUniforms:= AMatrixUniforms;
end;

procedure TShaderBlock.PrepareToDraw;
var
  i: Integer;
begin
  glUseProgram(_Program);

  for i := 0 to High(_IntegerUniforms) do
  if _IntegerUniforms[i].Info.Index >= 0 then
  case _IntegerUniforms[i].Info.Size of
    1: glUniform1iv(_IntegerUniforms[i].Info.Index, Length(_IntegerUniforms[i].Value), @_IntegerUniforms[i].Value[0]);
    2: glUniform2iv(_IntegerUniforms[i].Info.Index, Length(_IntegerUniforms[i].Value) div 2, @_IntegerUniforms[i].Value[0]);
    3: glUniform3iv(_IntegerUniforms[i].Info.Index, Length(_IntegerUniforms[i].Value) div 3, @_IntegerUniforms[i].Value[0]);
    4: glUniform4iv(_IntegerUniforms[i].Info.Index, Length(_IntegerUniforms[i].Value) div 4, @_IntegerUniforms[i].Value[0]);
  else
    raise ENotSupportedException.Create('Wrong uniform size');
  end;

  for i := 0 to High(_FloatUniforms) do
  if _FloatUniforms[i].Info.Index >= 0 then
  case _FloatUniforms[i].Info.Size of
    1: glUniform1fv(_FloatUniforms[i].Info.Index, Length(_FloatUniforms[i].Value), @_FloatUniforms[i].Value[0]);
    2: glUniform2fv(_FloatUniforms[i].Info.Index, Length(_FloatUniforms[i].Value) div 2, @_FloatUniforms[i].Value[0]);
    3: glUniform3fv(_FloatUniforms[i].Info.Index, Length(_FloatUniforms[i].Value) div 3, @_FloatUniforms[i].Value[0]);
    4: glUniform4fv(_FloatUniforms[i].Info.Index, Length(_FloatUniforms[i].Value) div 4, @_FloatUniforms[i].Value[0]);
  else
    raise ENotSupportedException.Create('Wrong uniform size');
  end;

  for i := 0 to High(_MatrixUniforms) do
  if _MatrixUniforms[i].MatrixInfo.Info.Index >= 0 then
  case _MatrixUniforms[i].MatrixInfo.Info.Size of
    2: glUniformMatrix2fv(_MatrixUniforms[i].MatrixInfo.Info.Index, _MatrixUniforms[i].MatrixInfo.Count, _MatrixUniforms[i].MatrixInfo.Transpose, @_MatrixUniforms[i].Value[0]);
    3: glUniformMatrix3fv(_MatrixUniforms[i].MatrixInfo.Info.Index, _MatrixUniforms[i].MatrixInfo.Count, _MatrixUniforms[i].MatrixInfo.Transpose, @_MatrixUniforms[i].Value[0]);
    4: glUniformMatrix4fv(_MatrixUniforms[i].MatrixInfo.Info.Index, _MatrixUniforms[i].MatrixInfo.Count, _MatrixUniforms[i].MatrixInfo.Transpose, @_MatrixUniforms[i].Value[0]);
  end;
end;

{ TTexturesInfo }

procedure TTexturesInfo.Activate;
var i: Integer;
begin
  for i := 0 to High(_Textures) do begin
    _Textures[i].Texture.Enable;
    //glEnable(_Textures[i].Texture.Target);
    glActiveTexture(_Textures[i].Index);
    _Textures[i].Texture.Bind;
    //glBindTexture(_Textures[i].Texture.Target, _Textures[i].Texture.Texture);
  end;
end;

constructor TTexturesInfo.Create(const ATextures: TArray<TTextureBlock>);
begin
  _Textures:= ATextures;
end;

constructor TTexturesInfo.Create(const ATextures: array of TTextureBlock);
var i: Integer;
begin
  if Length(_Textures) <> Length(ATextures) then begin
    _Textures:= nil;
    SetLength(_Textures, Length(ATextures));
  end;
  for i := 0 to High(ATextures) do
    _Textures[i]:= ATextures[i];
end;

procedure TTexturesInfo.Deactivate;
begin

end;

{ TDIP }

constructor TDIP.Create(const ABuffer: TVertexBufferObject;
  const AInitShader: TShaderBlock; const ATextures: TTexturesInfo;
  const AAttribIndicies: TArray<GLuint>; ABeginIndex, AEndIndex, AIndecesOffset,
  AIndecesCount: GLsizei);
begin
  _Buffer:= ABuffer;
  _InitShader:= AInitShader;
  _Textures:= ATextures;
  _AttribIndicies:= AAttribIndicies;
  _BeginIndex:= ABeginIndex;
  _EndIndex:= AEndIndex;
  _IndicesOffset:= AIndecesOffset;
  _IndicesCount:= AIndecesCount;
end;

procedure TDIP.Draw;
begin
  _InitShader.PrepareToDraw;
  _Textures.Activate;
  _Buffer.Draw(_BeginIndex, _EndIndex, _IndicesOffset, _IndicesCount, _AttribIndicies);
  _Textures.Deactivate;
end;

{ TTextureBlock }

constructor TTextureBlock.Create(AIndex: {$IFDEF OGL_USE_ENUMS}TTextureUnit{$ELSE}GLenum{$ENDIF}; const ATexture: TOGLTexture);
begin
  Index:= AIndex;//GL_TEXTURE0
  Texture:= ATexture;
end;

{ TBorderedText }

procedure TBorderedText.FreeContext;
begin
  Prepared.FreeContext;
end;

procedure TBorderedText.Draw;
begin
  glEnable({$IFDEF OGL_USE_ENUMS}TEnableCap.{$ENDIF}GL_SCISSOR_TEST);
  glScissor(BoundRect.Left, GlobalViewPortSizeInteger[1] - BoundRect.Bottom, BoundRect.Width, BoundRect.Height);
  ReadyToDraw.Draw;
  glDisable({$IFDEF OGL_USE_ENUMS}TEnableCap.{$ENDIF}GL_SCISSOR_TEST);
end;

{ TOGLTexture }

procedure TOGLTexture.Bind;
begin
  glBindTexture(Target, Texture);
end;

procedure TOGLTexture.Enable;
begin
  glEnable({$IFDEF OGL_USE_ENUMS}TEnableCap(Target){$ELSE}Target{$ENDIF});
end;

procedure TOGLTexture.FreeContext;
begin
  if GLenum(Target) <> 0 then begin
    glDeleteTextures(1, @Texture);
    Target:= {$IFDEF OGL_USE_ENUMS}TTextureTarget(0){$ELSE}0{$ENDIF};
  end;
end;

{ TPreparedText }

procedure TPreparedText.FreeContext;
begin
  Buffer.FreeContext;
end;

{ TVBOElementFormats }

class constructor TVBOElementFormats.Create;
begin
  Pointer(FElementFormatV2f):= @RawV2f.Arr;
  Pointer(FElementFormatV3f):= @RawV3f.Arr;
  Pointer(FElementFormatV2fT2f):= @RawV2fT2f.Arr;
  Pointer(FElementFormatV3fT2f):= @RawV3fT2f.Arr;
  Pointer(FElementFormatV2fT2fC4f):= @RawV2fT2fC4f.Arr;
  Pointer(FElementFormatV4fT2fC4f):= @RawV4fT2fC4f.Arr;
  Pointer(FElementFormatV4fT3fC4f):= @RawV4fT3fC4f.Arr;
end;

{ TBitmapFontBase }

procedure TBitmapFontBase.ActualizeState;
var newBuf, len: Integer;
begin
  DebugLogOutputAllErrors(TBitmapFont, Format('ActualizeState before [%d]', [LineHeight]));
  if FShouldToggle then begin
    FShouldToggle:= False;
    newBuf:= Integer(FCurrentCharData = @FCharBuffers[0]);
    if (FCharBuffers[0].TexWidth <> FCharBuffers[1].TexWidth) or
      (FCharBuffers[0].TexHeight <> FCharBuffers[1].TexHeight) then begin

      if FTextures._Textures = nil then
        ///  создать новую текстуру, если ещё не создана
        GenerateTexture;
      FTextures._Textures[0].Texture.Bind;

      FillTexture(FCharBuffers[newBuf].TexWidth, FCharBuffers[newBuf].TexHeight, @FCharBuffers[newBuf].TexData[0]);
    end else begin
      ///  обновить текстуру
      FTextures._Textures[0].Texture.Bind;

      glPixelStorei({$IFDEF OGL_USE_ENUMS}TPixelStoreParameter.{$ENDIF}GL_UNPACK_ALIGNMENT, 1);
      glTexSubImage2D({$IFDEF OGL_USE_ENUMS}TTextureTarget.{$ENDIF}GL_TEXTURE_2D, 0, 0, FCurrentCharData.YOffset, FCharBuffers[newBuf].TexWidth, FCharBuffers[newBuf].TexHeight - FCurrentCharData.YOffset,
        {$IFDEF OGL_USE_ENUMS}TPixelFormat.{$ENDIF}GL_RED, {$IFDEF OGL_USE_ENUMS}TPixelType.{$ENDIF}GL_UNSIGNED_BYTE, @FCharBuffers[newBuf].TexData[0]);
      DebugLogOutputAllErrors(TBitmapFontBase, Format('ActualizeState glTexSubImage2D [%d]', [LineHeight]));
    end;

    FCurrentCharData:= @FCharBuffers[newBuf];
    FRenderTask:= nil;
  end else if (FTextures._Textures = nil) and (FCurrentCharData.TexWidth <> 0) then begin
    GenerateTexture;
    FTextures._Textures[0].Texture.Bind;
    len:= FBMP.GetPixelsCount();
    if len <> Length(FCurrentCharData.TexData) then begin
      FCurrentCharData.TexData:= nil;
      SetLength(FCurrentCharData.TexData, len);
      FBMP.GetGrayscalePixels(FCurrentCharData.TexData);
    end;

    FillTexture(FCurrentCharData.TexWidth, FCurrentCharData.TexHeight, @FCurrentCharData.TexData[0]);
  end;
  DebugLogOutputAllErrors(TBitmapFont, Format('ActualizeState [%d]', [LineHeight]));

  if (FRenderTask = nil) and not FNeededLayers.IsEmpty then
    FRenderTask:= TTask.Run(Self, Initialize);
end;

procedure TBitmapFontBase.AddNewLayer(ALayer: Cardinal);
begin
  FNeededLayers.Push(ALayer);
end;

constructor TBitmapFontBase.Create(const AFont: TFontData;
  const ADefaultCharAndStartLayers: string);
var p: PWideChar;
    u: UCS4Char;
    last: LongWord;
    //m: TOutlineTextmetricW;
begin
  FFont.Create(AFont);
  FFont.Color:= $FFFFFF;
  if ADefaultCharAndStartLayers = '' then
    p:= #$FFFD
  else
    p:= PWideChar(Pointer(ADefaultCharAndStartLayers));
  FDefaultChar:= SurrogateToUCS4Char(p);
  if IsFirstSurrogateChar(p^) then
    Inc(p);
  Inc(p);
  last:= FDefaultChar shr 8;
  FNeededLayers.Push(last);
  while p^ <> #0 do begin
    u:= SurrogateToUCS4Char(p);
    if IsFirstSurrogateChar(p^) then
      Inc(p);
    Inc(p);
    if last <> u shr 8 then begin
      last:= u shr 8;
      FNeededLayers.Push(last);
    end;
  end;
  FCurrentCharData:= @FCharBuffers[0];

  if (FRenderTask = nil) and not FNeededLayers.IsEmpty then
    FRenderTask:= TTask.Run(Self, Initialize);
end;

destructor TBitmapFontBase.Destroy;
var task: ITask;
begin
  Assert(FTextures._Textures = nil);
  task:= FRenderTask;
  if task <> nil then
    task.Wait();
  FFont.Destroy;
  FCharBuffers[0].Clear;
  FCharBuffers[1].Clear;
  FBMP.Destroy;
  inherited;
end;

procedure TBitmapFontBase.FillTexture(TexWidth, TexHeight: Integer; TexData: Pointer);
begin
  glPixelStorei({$IFDEF OGL_USE_ENUMS}TPixelStoreParameter.{$ENDIF}GL_UNPACK_ALIGNMENT, 1);
  DebugLogOutputAllErrors(TBitmapFontBase, Format('FillTexture GL_UNPACK_ALIGNMENT [%d]', [LineHeight]));
  glTexEnvi({$IFDEF OGL_USE_ENUMS}TTextureEnvTarget.{$ENDIF}GL_TEXTURE_ENV, {$IFDEF OGL_USE_ENUMS}TTextureEnvParameter.{$ENDIF}GL_TEXTURE_ENV_MODE, GL_MODULATE);//}GL_DECAL );
  DebugLogOutputAllErrors(TBitmapFontBase, Format('FillTexture GL_TEXTURE_ENV GL_TEXTURE_ENV_MODE [%d]', [LineHeight]));
  glTexParameteri({$IFDEF OGL_USE_ENUMS}TTextureTarget.{$ENDIF}GL_TEXTURE_2D, {$IFDEF OGL_USE_ENUMS}TTextureParameterName.{$ENDIF}GL_TEXTURE_WRAP_S, GL_REPEAT);
  DebugLogOutputAllErrors(TBitmapFontBase, Format('FillTexture GL_TEXTURE_WRAP_S [%d]', [LineHeight]));
  glTexParameteri({$IFDEF OGL_USE_ENUMS}TTextureTarget.{$ENDIF}GL_TEXTURE_2D, {$IFDEF OGL_USE_ENUMS}TTextureParameterName.{$ENDIF}GL_TEXTURE_WRAP_T, GL_REPEAT);
  DebugLogOutputAllErrors(TBitmapFontBase, Format('FillTexture GL_TEXTURE_WRAP_T [%d]', [LineHeight]));
  //glHint({$IFDEF OGL_USE_ENUMS}THintTarget.{$ENDIF}GL_PERSPECTIVE_CORRECTION_HINT, {$IFDEF OGL_USE_ENUMS}THintMode.{$ENDIF}GL_FASTEST );
  glTexParameteri({$IFDEF OGL_USE_ENUMS}TTextureTarget.{$ENDIF}GL_TEXTURE_2D, {$IFDEF OGL_USE_ENUMS}TTextureParameterName.{$ENDIF}GL_TEXTURE_MAG_FILTER, GLint({$IFDEF OGL_USE_ENUMS}TTextureMagFilter.{$ENDIF}GL_NEAREST));
  DebugLogOutputAllErrors(TBitmapFontBase, Format('FillTexture GL_TEXTURE_MAG_FILTER [%d]', [LineHeight]));
  glTexParameteri({$IFDEF OGL_USE_ENUMS}TTextureTarget.{$ENDIF}GL_TEXTURE_2D, {$IFDEF OGL_USE_ENUMS}TTextureParameterName.{$ENDIF}GL_TEXTURE_MIN_FILTER, GLint({$IFDEF OGL_USE_ENUMS}TTextureMinFilter.{$ENDIF}GL_NEAREST));
  DebugLogOutputAllErrors(TBitmapFontBase, Format('FillTexture GL_TEXTURE_MIN_FILTER [%d]', [LineHeight]));
  glTexImage2D({$IFDEF OGL_USE_ENUMS}TTextureTarget.{$ENDIF}GL_TEXTURE_2D, 0, {$IFDEF OGL_USE_ENUMS}TInternalFormat.{$ENDIF}GL_LUMINANCE8, TexWidth, TexHeight, 0,
    {$IFDEF OGL_USE_ENUMS}TPixelFormat.{$ENDIF}GL_RED, {$IFDEF OGL_USE_ENUMS}TPixelType.{$ENDIF}GL_UNSIGNED_BYTE, TexData);
  DebugLogOutputAllErrors(TBitmapFontBase, Format('FillTexture glTexImage2D [%d] W:%d H:%d', [LineHeight, TexWidth, TexHeight]));
end;

procedure TBitmapFontBase.FreeContext;
begin
  if FTextures._Textures <> nil then begin
    glDeleteTextures(1, @FTextures._Textures[0].Texture.Texture);
    FTextures._Textures:= nil;
  end;
end;

procedure TBitmapFontBase.GenerateTexture;
var texture: TOGLTexture;
begin
  texture.Target:= {$IFDEF OGL_USE_ENUMS}TTextureTarget.{$ENDIF}GL_TEXTURE_2D;
  glGenTextures(1, @texture.Texture);
  FTextures.Create([TTextureBlock.Create({$IFDEF OGL_USE_ENUMS}TTextureUnit.{$ENDIF}GL_TEXTURE0, texture)]);
end;

function TBitmapFontBase.GetCharInfo(AChar: UCS4Char): PBitmapCharBlock;
begin
  Result:= FCurrentCharData.CharTable[AChar shr 8];
end;

function TBitmapFontBase.GetTextInfo(const AText: string; out AInfo: TTextInfo;
  DefaultWidth, SpaceWidth, MaxWidth: Integer; AAlign: TTextAlign; Wrap: Boolean): Boolean;
var xOfs, C, wordBeginOfs, wordBeginChar, spaceCount: Integer;
    ps: PChar;
    textWidth: Integer;
    pb: PBitmapCharBlock;
    Cur: UCS4Char;
    LineIndicies: TListRecord<Integer>;
    lines: TListRecord<TLineInfo>;
    spaceChainLength: Integer;
    firstSpaceOfs: Integer;
    lastIsSpace: Boolean;
  procedure AddLineWrap(align: TTextAlign; Ofs, SpaceWidth, EndChar, SpaceCount: Integer);
  begin
    if AInfo.MaxWidth < Ofs then
      AInfo.MaxWidth:= Ofs;
    LineIndicies.Add(EndChar);
    case align of
      taJustify:
        if SpaceCount > 0 then
          lines.Add(TLineInfo.Create(0, SpaceWidth + (MaxWidth - Ofs) div SpaceCount))
        else
          lines.Add(TLineInfo.Create(0, SpaceWidth));
      taLeft: lines.Add(TLineInfo.Create(0, SpaceWidth));
      taRight: lines.Add(TLineInfo.Create(MaxWidth - Ofs, SpaceWidth));
      taCenterAlinment: lines.Add(TLineInfo.Create((MaxWidth - Ofs) div 2, SpaceWidth));
    end;
  end;
  procedure AddLineBreak(align: TTextAlign; Ofs, SpaceWidth, EndChar, SpaceCount: Integer);
  begin
    if AInfo.MaxWidth < Ofs then
      AInfo.MaxWidth:= Ofs;
    LineIndicies.Add(EndChar);
    case align of
      taJustify, taLeft: lines.Add(TLineInfo.Create(0, SpaceWidth));
      taRight: lines.Add(TLineInfo.Create(MaxWidth - Ofs, SpaceWidth));
      taCenterAlinment: lines.Add(TLineInfo.Create((MaxWidth - Ofs) div 2, SpaceWidth));
    end;
  end;
var
  last: Cardinal;
  SkipControlSymbolsLoc: function (var TextPointer: PChar): Boolean of object;
begin
  Result:= True;
  spaceChainLength:= 0;
  firstSpaceOfs:= 0;
  ps:= Pointer(AText);
  C:= 0;
  xOfs:= 0;
  wordBeginOfs:= 0;
  wordBeginChar:= 0;
  spaceCount:= 0;
  lines.Create(10);
  LineIndicies.Create(10);
  lastIsSpace:= False;
  AInfo.MaxWidth:= 0;
  last:= Ord(' ') shr 8;

  SkipControlSymbolsLoc:= SkipControlSymbols;

  while ps^ <> #0 do begin
    Cur:= SurrogateToUCS4Char(ps);
    case Cur of
      Ord(' '): begin
          if not lastIsSpace then begin
            spaceChainLength:= 0;
            firstSpaceOfs:= xOfs;
            lastIsSpace:= True;
          end;
          //пропускаем пробелы в начале строки
          if xOfs <> 0 then begin
            Inc(spaceChainLength);
            Inc(xOfs, SpaceWidth);
            Inc(spaceCount);
            wordBeginOfs:= xOfs;
            wordBeginChar:= C;
          end;
        end;
      {$IFNDEF USE10AS13}
      10: begin
        {$IFDEF SKIP10}
          xOfs:= 0;
          wordBeginOfs:= 0;
          lastIsSpace:= False;
        {$ENDIF}
        end;
      {$ENDIF}
      13 {$IFDEF USE10AS13}, 10{$ENDIF}: begin
          if lastIsSpace then
            AddLineBreak(AAlign, firstSpaceOfs, SpaceWidth, C, spaceCount - spaceChainLength)
          else
            AddLineBreak(AAlign, xOfs, SpaceWidth, C, spaceCount - spaceChainLength);
          spaceCount:= 0;
          wordBeginOfs:= 0;
          {$IFDEF SKIP10}xOfs:= 0;{$ENDIF}
          lastIsSpace:= False;
        end;
    else
      if SkipControlSymbolsLoc(ps) then
        Continue;
      pb:= GetCharInfo(Cur);
      if pb <> nil then
        textWidth:= pb.Width[Cur and $FF]
      else begin
        if last <> Cur shr 8 then begin
          last:= Cur shr 8;
          AddNewLayer(last);
        end;
        Result:= False;
        textWidth:= DefaultWidth;
      end;
      if (textWidth + xOfs >= MaxWidth) and Wrap then begin
        if wordBeginOfs = 0 then begin
          AddLineWrap(AAlign, xOfs, SpaceWidth, C, spaceCount - spaceChainLength);
          xOfs:= 0;
        end else begin
          AddLineWrap(AAlign, firstSpaceOfs, SpaceWidth, wordBeginChar, spaceCount - spaceChainLength);
          xOfs:= xOfs - wordBeginOfs;
          wordBeginOfs:= 0;
        end;
      end;
      lastIsSpace:= False;
      Inc(xOfs, textWidth);
      if IsFirstSurrogateChar(ps^) then
        Inc(ps);
      Inc(C);
    end;
    Inc(ps);
  end;
  // последний указывает на последний символ
  if lastIsSpace then
    AddLineBreak(AAlign, firstSpaceOfs, SpaceWidth, C, spaceCount - spaceChainLength)
  else
    AddLineBreak(AAlign, xOfs, SpaceWidth, C, spaceCount - spaceChainLength);

  AInfo.SymbolsCount:= C;
  LineIndicies.TrimExcess;
  AInfo.LineEndSymbolIndex:= LineIndicies.List;
  lines.TrimExcess;
  AInfo.LinesAlignment:= lines.List;
end;

function TBitmapFontBase.GetTextInfo(const AText: string; out AInfo: TTextInfo;
  DefaultWidth, SpaceWidth: Integer): Boolean;
var xOfs, C: Integer;
    ps: PChar;
    textWidth: Integer;
    pb: PBitmapCharBlock;
    Cur: UCS4Char;
    LineIndicies: TListRecord<Integer>;
    lines: TListRecord<TLineInfo>;
    last: Cardinal;
  procedure AddLineBreak(Ofs, SpaceWidth, EndChar: Integer);
  begin
    if AInfo.MaxWidth < Ofs then
      AInfo.MaxWidth:= Ofs;
    LineIndicies.Add(EndChar);
    lines.Add(TLineInfo.Create(0, SpaceWidth))
  end;
begin
  Result:= True;
  ps:= Pointer(AText);
  C:= 0;
  xOfs:= 0;
  lines.Create(10);
  LineIndicies.Create(10);
  AInfo.MaxWidth:= 0;
  last:= Ord(' ') shr 8;

  while ps^ <> #0 do begin
    Cur:= SurrogateToUCS4Char(ps);
    case Cur of
      Ord(' '): Inc(xOfs, SpaceWidth);
      {$IFNDEF USE10AS13}
      10: begin
        {$IFDEF SKIP10}xOfs:= 0;{$ENDIF}
      end;
      {$ENDIF}
      13 {$IFDEF USE10AS13}, 10{$ENDIF}: begin
        AddLineBreak(xOfs, SpaceWidth, C);
        {$IFDEF SKIP10}xOfs:= 0;{$ENDIF}
      end;
    else
      if SkipControlSymbols(ps) then
        Continue;
      pb:= GetCharInfo(Cur);
      if pb <> nil then
        textWidth:= pb.Width[Cur and $FF]
      else begin
        if last <> Cur shr 8 then begin
          last:= Cur shr 8;
          AddNewLayer(last);
        end;
        Result:= False;
        textWidth:= DefaultWidth;
      end;
      Inc(xOfs, textWidth);
      if IsFirstSurrogateChar(ps^) then
        Inc(ps);
      Inc(C);
    end;
    Inc(ps);
  end;
  // последний указывает на последний символ
  AddLineBreak(xOfs, SpaceWidth, C);

  AInfo.SymbolsCount:= C;
  LineIndicies.TrimExcess;
  AInfo.LineEndSymbolIndex:= LineIndicies.List;
  lines.TrimExcess;
  AInfo.LinesAlignment:= lines.List;
end;

function TBitmapFontBase.GetTextInfo(const AText: string;
  out AInfo: TTextInfo): Boolean;
var SpaceWidth: Integer;
    pb, def: PBitmapCharBlock;
begin
  Result:= True;
  if AText = '' then Exit;
  def:= GetCharInfo(DefaultChar);
  if def = nil then
    Exit(False);
  pb:= GetCharInfo(Ord(' '));
  if pb <> nil then
    SpaceWidth:= pb.Width[Ord(' ')]
  else begin
    AddNewLayer(Ord(' ') shr 8);
    SpaceWidth:= def.Width[Ord(DefaultChar) and $FF];
    Result:= False;
  end;

  Result:= GetTextInfo(AText, AInfo, def.Width[Ord(DefaultChar) and $FF], SpaceWidth) and Result;
end;

function TBitmapFontBase.GetTextInfoByIndex(const AText: string;
  out AInfo: TTextInfo; DefaultWidth, SpaceWidth, MaxWidth: Integer;
  AAlign: TTextAlign; Wrap: Boolean): Boolean;
var xOfs, wordBeginOfs, wordBeginChar, spaceCount: Integer;
    ps: PChar;
    textWidth: Integer;
    pb: PBitmapCharBlock;
    Cur: UCS4Char;
    LineIndicies: TListRecord<Integer>;
    lines: TListRecord<TLineInfo>;
    spaceChainLength: Integer;
    firstSpaceOfs: Integer;
    lastIsSpace: Boolean;
  procedure AddLineWrap(align: TTextAlign; Ofs, SpaceWidth, EndChar, SpaceCount: Integer);
  begin
    if AInfo.MaxWidth < Ofs then
      AInfo.MaxWidth:= Ofs;
    LineIndicies.Add(EndChar);
    case align of
      taJustify:
        if SpaceCount > 0 then
          lines.Add(TLineInfo.Create(0, SpaceWidth + (MaxWidth - Ofs) div SpaceCount))
        else
          lines.Add(TLineInfo.Create(0, SpaceWidth));
      taLeft: lines.Add(TLineInfo.Create(0, SpaceWidth));
      taRight: lines.Add(TLineInfo.Create(MaxWidth - Ofs, SpaceWidth));
      taCenterAlinment: lines.Add(TLineInfo.Create((MaxWidth - Ofs) div 2, SpaceWidth));
    end;
  end;
  procedure AddLineBreak(align: TTextAlign; Ofs, SpaceWidth, EndChar, SpaceCount: Integer);
  begin
    if AInfo.MaxWidth < Ofs then
      AInfo.MaxWidth:= Ofs;
    LineIndicies.Add(EndChar);
    case align of
      taJustify, taLeft: lines.Add(TLineInfo.Create(0, SpaceWidth));
      taRight: lines.Add(TLineInfo.Create(MaxWidth - Ofs, SpaceWidth));
      taCenterAlinment: lines.Add(TLineInfo.Create((MaxWidth - Ofs) div 2, SpaceWidth));
    end;
  end;
var
  last: Cardinal;
  textBegin: PChar;
  SkipControlSymbolsLoc: function (var TextPointer: PChar): Boolean of object;
begin
  Result:= True;
  spaceChainLength:= 0;
  firstSpaceOfs:= 0;
  ps:= Pointer(AText);
  textBegin:= ps;
  xOfs:= 0;
  wordBeginOfs:= 0;
  wordBeginChar:= 0;
  spaceCount:= 0;
  lines.Create(10);
  LineIndicies.Create(10);
  lastIsSpace:= False;
  AInfo.MaxWidth:= 0;
  last:= Ord(' ') shr 8;

  SkipControlSymbolsLoc:= SkipControlSymbols;

  while ps^ <> #0 do begin
    Cur:= SurrogateToUCS4Char(ps);
    case Cur of
      Ord(' '): begin
          if not lastIsSpace then begin
            spaceChainLength:= 0;
            firstSpaceOfs:= xOfs;
            lastIsSpace:= True;
            wordBeginChar:= ps - textBegin;
          end;
          //пропускаем пробелы в конце строки
          if xOfs <> 0 then begin
            Inc(spaceChainLength);
            Inc(xOfs, SpaceWidth);
            Inc(spaceCount);
            wordBeginOfs:= xOfs;
          end;
        end;
      {$IFNDEF USE10AS13}
      10: begin
        {$IFDEF SKIP10}
          xOfs:= 0;
          wordBeginOfs:= 0;
          lastIsSpace:= False;
        {$ENDIF}
        end;
      {$ENDIF}
      13 {$IFDEF USE10AS13}, 10{$ENDIF}: begin
          if lastIsSpace then
            AddLineBreak(AAlign, firstSpaceOfs, SpaceWidth, ps - textBegin, spaceCount - spaceChainLength)
          else
            AddLineBreak(AAlign, xOfs, SpaceWidth, ps - textBegin, spaceCount - spaceChainLength);
          spaceCount:= 0;
          wordBeginOfs:= 0;
          {$IFDEF SKIP10}xOfs:= 0;{$ENDIF}
          lastIsSpace:= False;
        end;
    else
      if SkipControlSymbolsLoc(ps) then
        Continue;
      pb:= GetCharInfo(Cur);
      if pb <> nil then
        textWidth:= pb.Width[Cur and $FF]
      else begin
        if last <> Cur shr 8 then begin
          last:= Cur shr 8;
          AddNewLayer(last);
        end;
        Result:= False;
        textWidth:= DefaultWidth;
      end;
      if (textWidth + xOfs >= MaxWidth) and Wrap then begin
        if wordBeginOfs = 0 then begin
          AddLineWrap(AAlign, xOfs, SpaceWidth, ps - textBegin, spaceCount - spaceChainLength);
          xOfs:= 0;
        end else begin
          AddLineWrap(AAlign, firstSpaceOfs, SpaceWidth, wordBeginChar, spaceCount - spaceChainLength);
          xOfs:= xOfs - wordBeginOfs;
          wordBeginOfs:= 0;
        end;
      end;
      lastIsSpace:= False;
      Inc(xOfs, textWidth);
      if IsFirstSurrogateChar(ps^) then
        Inc(ps);
    end;
    Inc(ps);
  end;
  // последний указывает на последний символ
  if lastIsSpace then
    AddLineBreak(AAlign, firstSpaceOfs, SpaceWidth, ps - textBegin, spaceCount - spaceChainLength)
  else
    AddLineBreak(AAlign, xOfs, SpaceWidth, ps - textBegin, spaceCount - spaceChainLength);

  AInfo.SymbolsCount:= ps - textBegin;
  LineIndicies.TrimExcess;
  AInfo.LineEndSymbolIndex:= LineIndicies.List;
  lines.TrimExcess;
  AInfo.LinesAlignment:= lines.List;
end;

function TBitmapFontBase.GetTextSize(const AText: string; MaxWidth: Integer;
  AAlign: TTextAlign; Wrap: Boolean): TPoint;
var SpaceWidth: Integer;
    pb, Default: PBitmapCharBlock;
    info: TTextInfo;
begin
  Result.Create(0, LineHeight);
  if AText = '' then Exit;
  Default:= GetCharInfo(DefaultChar);
  if Default <> nil then begin
    pb:= GetCharInfo(Ord(' '));
    if pb <> nil then
      SpaceWidth:= pb.Width[Ord(' ')]
    else
      SpaceWidth:= Default.Width[Ord(DefaultChar) and $FF];

    GetTextInfo(AText, info, Default.Width[Ord(DefaultChar) and $FF], SpaceWidth, MaxWidth, AAlign, Wrap);

    Result.X:= info.MaxWidth;
    Result.Y:= Length(info.LineEndSymbolIndex) * LineHeight;
  end;
end;

function TBitmapFontBase.GetTextInfo(const AText: string; out AInfo: TTextInfo;
  MaxWidth: Integer; AAlign: TTextAlign; Wrap: Boolean): Boolean;
var SpaceWidth: Integer;
    pb, def: PBitmapCharBlock;
begin
  Result:= True;
  if AText = '' then Exit;
  def:= GetCharInfo(DefaultChar);
  if def = nil then
    Exit(False);
  pb:= GetCharInfo(Ord(' '));
  if pb <> nil then
    SpaceWidth:= pb.Width[Ord(' ')]
  else begin
    AddNewLayer(Ord(' ') shr 8);
    SpaceWidth:= def.Width[Ord(DefaultChar) and $FF];
    Result:= False;
  end;

  Result:= GetTextInfo(AText, AInfo, def.Width[Ord(DefaultChar) and $FF], SpaceWidth, MaxWidth, AAlign, Wrap) and Result;
end;

procedure TBitmapFontBase.Initialize(Sender: TObject);
var
  i, Index: Integer;
  w, h: Integer;
  buf: PBitmapFontData;
  table: PBitmapCharBlock;
  renderChar: array [0..2] of WideChar;
  XOfs, YOfs: Integer;
  j, k, fix: Integer;
  m: TOutlineTextmetricW;
begin
  if FCurrentCharData = @FCharBuffers[0] then
    buf:= @FCharBuffers[1]
  else
    buf:= @FCharBuffers[0];

  buf.Clear;
  if FCurrentCharData <> nil then begin
    buf.TexWidth:= FCurrentCharData.TexWidth;
    buf.TexHeight:= FCurrentCharData.TexHeight;
    buf.XOffset:= FCurrentCharData.XOffset;
    buf.YOffset:= FCurrentCharData.YOffset;
    for i := 0 to High(FCurrentCharData.CharTable) do
      if FCurrentCharData.CharTable[i] <> nil then begin
        New(buf.CharTable[i]);
        buf.CharTable[i]^:= FCurrentCharData.CharTable[i]^;
      end;
  end;


  if not FBMP.IsInitialized then begin
    FBMP.Initialize;
    FBMP.Lock;
    try
      FBMP.Font:= FFont;
      if GetOutlineTextMetrics(FBMP.GetDC, SizeOf(m), @m) = 0 then
        RaiseLastOSError(GetLastError, ' TBitmapFontBase.Initialize GetOutlineTextMetrics');
      FHeight:= m.otmTextMetrics.tmHeight;
      FLineHeight:= FHeight + m.otmTextMetrics.tmExternalLeading;
      buf.TexWidth:= 1 shl (GetMaxIndexOfSetBit(FHeight * 16) + 1);
      buf.TexHeight:= 1 shl (GetMaxIndexOfSetBit(FHeight * 4) + 1);
      FBMP.SetBound(buf.TexWidth, buf.TexHeight);
    finally
      FBMP.Unlock;
    end;
  end;

  while not FNeededLayers.IsEmpty do begin
    Index:= FNeededLayers.Pop;
    if buf.CharTable[Index] = nil then begin
      New(table);
      try

        FBMP.Lock;
        try
          if not GetCharABCWidths(FBMP.GetDC, Index shl 8, Index shl 8 + $FF, table.ABC) then
            RaiseLastOSError(GetLastError, ' TBitmapFontBase.Initialize GetCharABCWidths');

          w:= FBMP.Width;
          h:= FBMP.Height;
          XOfs:= buf.XOffset;
          YOfs:= buf.YOffset;
          //if table.ABC[0].abcA > 0 then
          //  Inc(XOfs, table.ABC[0].abcA);//+1 for correction
          for i := 0 to 255 do begin
            table.Width[i]:= table.ABC[i].abcB + table.ABC[i].abcA + table.ABC[i].abcC;
            fix:= table.ABC[i].abcB;// Max(table.ABC[i].abcB, table.Width[i]); //cause some fonts lie about real B
            if XOfs + fix + 2 > w then begin
              XOfs:= 0;
              Inc(YOfs, FLineHeight);
            end;

            if YOfs + FHeight > h then begin
              h:= h * 2;
              //FBMP.Unlock;
              FBMP.SetBound(w, h);
              //FBMP.Lock;
              for j := 0 to High(buf.CharTable) do
              if buf.CharTable[j] <> nil then with buf.CharTable[j]^ do
                for k:= 0 to 255 do begin
                  TexCoord[k, 0, 1]:= TexCoord[k, 0, 1] / 2;
                  TexCoord[k, 1, 1]:= TexCoord[k, 1, 1] / 2;
                  TexCoord[k, 2, 1]:= TexCoord[k, 2, 1] / 2;
                  TexCoord[k, 3, 1]:= TexCoord[k, 3, 1] / 2;
                end;
              with table^ do
                for k:= 0 to i - 1 do begin
                  TexCoord[k, 0, 1]:= TexCoord[k, 0, 1] / 2;
                  TexCoord[k, 1, 1]:= TexCoord[k, 1, 1] / 2;
                  TexCoord[k, 2, 1]:= TexCoord[k, 2, 1] / 2;
                  TexCoord[k, 3, 1]:= TexCoord[k, 3, 1] / 2;
                end;
            end;

            renderChar[UCS4ToSurrogate(Index shl 8 + i, renderChar)]:= #0;
            {if chr(i) = '"' then begin
              GetCharWidth(FBMP.GetDC, i, i, buf.YOffset);
            end;}
            FBMP.TextOut(renderChar, XOfs - table.ABC[i].abcA, YOfs);

            table.TexCoord[i, 1, 0]:= (XOfs - 1) / w;
            table.TexCoord[i, 1, 1]:= (YOfs) / h;

            table.TexCoord[i, 2, 0]:= (XOfs - 1) / w;
            table.TexCoord[i, 2, 1]:= (YOfs + FHeight) / h;

            Inc(XOfs, fix + 2);
            table.TexCoord[i, 0, 0]:= (XOfs - 1) / w;
            table.TexCoord[i, 0, 1]:= (YOfs) / h;

            table.TexCoord[i, 3, 0]:= (XOfs - 1) / w;
            table.TexCoord[i, 3, 1]:= (YOfs + FHeight) / h;
          end;
        finally
          FBMP.Unlock;
        end;

        buf.XOffset:= XOfs;
        buf.YOffset:= YOfs;
        buf.CharTable[Index]:= table;
      except
        Dispose(table);
        raise;
      end;
    end;
  end;
  if (FCurrentCharData.XOffset <> buf.XOffset) or
      (FCurrentCharData.YOffset <> buf.YOffset) then begin
    buf.TexWidth:= FBMP.Width;
    buf.TexHeight:= FBMP.Height;
    buf.TexData:= nil;
    if (buf.TexWidth <> FCurrentCharData.TexWidth) or
        (buf.TexHeight <> FCurrentCharData.TexHeight) then
      YOfs:= 0
    else
      YOfs:= FCurrentCharData.YOffset;
    //FBMP.SaveToFile('C:\Users\Administrator\Desktop\unity\' + IntToStr(FFont.Size) + '--' + IntToStr(Round(Now * SecsPerDay * 1000.0)) + '.bmp');
    SetLength(buf.TexData, FBMP.GetPixelsCount(YOfs));
    FBMP.GetGrayscalePixels(buf.TexData, YOfs);
    FShouldToggle:= True;
    TThread.Queue(TThread.CurrentThread, ReadyToToggle);
  end else
    FRenderTask:= nil;
end;

function TBitmapFontBase.IsSameFornt(const AFont: TFontData): Boolean;
begin
  Result:= FFont = AFont;
end;

procedure TBitmapFontBase.ReadyToToggle;
begin

end;

function TBitmapFontBase.SkipControlSymbols(var TextPointer: PChar): Boolean;
begin
  Result:= False;
end;

function TBitmapFontBase.TextureSymbolHeight: GLfloat;
begin
  if FCurrentCharData.TexHeight <> 0 then
    Result:= FHeight / FCurrentCharData.TexHeight
  else
    Result:= 0;
end;

{ TLineInfo }

constructor TLineInfo.Create(AOffsetX, ASpaceWidth: Integer);
begin
  OffsetX:= AOffsetX;
  SpaceWidth:= ASpaceWidth;
end;

{ TVBOElements }

procedure TVBOElements.Bind;
begin
  glBindBuffer({$IFDEF OGL_USE_ENUMS}TBufferTargetARB.{$ENDIF}GL_ARRAY_BUFFER, _Elements);
end;

constructor TVBOElements.Copy(const AElement: TVBOElements);
begin
  FreeContext;
  _Elements:= AElement.Elements;
  TSystemTypesHelpers.CopyArrayAsConst<TVBOElementFormat>(_ElementsFormat, AElement._ElementsFormat);
end;

constructor TVBOElements.Create(const AElementsFormat: TArray<TVBOElementFormat>;
    AElements: GLuint);
begin
  _Elements:= AElements;
  TSystemTypesHelpers.CopyArrayAsConst<TVBOElementFormat>(_ElementsFormat, AElementsFormat);
end;

procedure TVBOElements.Disable(const AttribIndicies: array of GLuint);
var
  i: Integer;
begin
  for i := Low(AttribIndicies) to Min(High(AttribIndicies), High(_ElementsFormat)) do
  if AttribIndicies[i] <> UnusedAttrib then
    glDisableVertexAttribArray(AttribIndicies[i]);
end;

function TVBOElements.ElementFormatsCount: Integer;
begin
  Result:= Length(_ElementsFormat);
end;

procedure TVBOElements.EnableAttributes(const AttribIndicies: array of GLuint);
var
  i: Integer;
begin
  for i := Low(AttribIndicies) to Min(High(AttribIndicies), High(_ElementsFormat)) do
  if AttribIndicies[i] <> UnusedAttrib then begin
    glEnableVertexAttribArray(AttribIndicies[i]);
    case _ElementsFormat[i].BindFunction of
      bfDefault: glVertexAttribPointer(AttribIndicies[i], _ElementsFormat[i].Size,
          _ElementsFormat[i].{$IFDEF OGL_USE_ENUMS}FloatType{$ELSE}DataType{$ENDIF}, _ElementsFormat[i].Normalized, _ElementsFormat[i].Stride, Pointer(_ElementsFormat[i].Offset));
      (*bfInteger: glVertexAttribIPointer(AttribIndicies[i], _ElementsFormat[i].Size,
          _ElementsFormat[i].{$IFDEF OGL_USE_ENUMS}IntegerType{$ELSE}DataType{$ENDIF}, _ElementsFormat[i].Stride, Pointer(_ElementsFormat[i].Offset));*)
      bfDouble:
        raise ENotSupportedException.Create('bfDouble');
        //glVertexAttribLPointer(AttribIndicies[i], _ElementsFormat[i].Size, _ElementsFormat[i].DataType, Byte(_ElementsFormat[i].Normalized), _ElementsFormat[i].Stride, Pointer(_ElementsFormat[i].Offset));
    end;
  end;
end;

procedure TVBOElements.FreeContext;
begin
  if _Elements <> 0 then begin
    glDeleteBuffers(1, @_Elements);
    _Elements:= 0;
  end;
end;

constructor TVBOElements.New(const AElementsFormat: TArray<TVBOElementFormat>);
begin
  FreeContext;
  glGenBuffers(1, @_Elements);
  TSystemTypesHelpers.CopyArrayAsConst<TVBOElementFormat>(_ElementsFormat, AElementsFormat);
end;

procedure TVBOElements.UnBind;
begin
  glBindBuffer({$IFDEF OGL_USE_ENUMS}TBufferTargetARB.{$ENDIF}GL_ARRAY_BUFFER, 0);
end;

{ TVBOIndices }

procedure TVBOIndices.Bind;
begin
  glBindBuffer({$IFDEF OGL_USE_ENUMS}TBufferTargetARB.{$ENDIF}GL_ELEMENT_ARRAY_BUFFER, _Indices);
end;

constructor TVBOIndices.Copy(const AIndeces: TVBOIndices);
begin
  FreeContext;
  _Indices:= AIndeces._Indices;
  _IndicesType:= AIndeces._IndicesType;
  _IndicesCount:= AIndeces._IndicesCount;
  _IndicesStride:= AIndeces._IndicesStride;
end;

constructor TVBOIndices.Create(AIndeces: GLuint; AIndecesType: {$IFDEF OGL_USE_ENUMS}TDrawElementsType{$ELSE}GLenum{$ENDIF};
  AIndecesCount, AIndecesStride: GLsizei);
begin
  _Indices:= AIndeces;
  _IndicesType:= AIndecesType;
  _IndicesCount:= AIndecesCount;
  _IndicesStride:= AIndecesStride;
end;

procedure TVBOIndices.Draw(mode: {$IFDEF OGL_USE_ENUMS}TPrimitiveType{$ELSE}GLenum{$ENDIF};
  BeginIndex, EndIndex, IndicesOffset, IndicesCount: GLsizei);
begin
  glDrawRangeElements(mode, BeginIndex, EndIndex, IndicesCount, _IndicesType, Pointer(IndicesOffset * _IndicesStride));
end;

procedure TVBOIndices.FreeContext;
begin
  if _Indices <> 0 then begin
    glDeleteBuffers(1, @_Indices);
    _Indices:= 0;
  end;
end;

constructor TVBOIndices.New(AIndecesType: {$IFDEF OGL_USE_ENUMS}TDrawElementsType{$ELSE}GLenum{$ENDIF}; AIndecesCount,
  AIndecesStride: GLsizei);
begin
  FreeContext;
  glGenBuffers(1, @_Indices);
  _IndicesType:= AIndecesType;
  _IndicesCount:= AIndecesCount;
  _IndicesStride:= AIndecesStride;
end;

procedure TVBOIndices.UnBind;
begin
  glBindBuffer({$IFDEF OGL_USE_ENUMS}TBufferTargetARB.{$ENDIF}GL_ELEMENT_ARRAY_BUFFER, 0);
end;

{ TProgramInfo }

procedure TProgramInfo.AttachAll;
var
  i: Integer;
begin
  for i := 0 to High(_Shaders) do
    glAttachShader(_Program, _Shaders[i]);
end;

constructor TProgramInfo.Create(AProgram: GLuint;
  const AShaders: array of GLuint);
begin
  _Program:= AProgram;
  _Shaders:= nil;
  SetLength(_Shaders, Length(AShaders));
  Move(AShaders[0], _Shaders[0], Length(AShaders) * SizeOf(GLuint));
end;

{ TGLContext }

function TGLContext.CreateOpenGLContext(DC: HDC; Throw: Boolean): Integer;
begin
  wglMakeCurrent( 0, 0);
  //DC := GetDC(Handle);
  SetDCPixelFormat(DC, PF);
  //ReleaseDC(DC, Handle);
  //DC := GetDC(Handle);
  GLRC := wglCreateContext(DC);
  if GLRC = 0 then
    RaiseLastOSError(GetLastError, 'Creating render context fail.');
  if not wglMakeCurrent(DC, GLRC) and Throw then
    RaiseLastOSError;
end;

function TGLContext.CreateOpenGLContext(DC: HDC; MajorVersion, MinorVersion,
  Flags, ProfileMask: LongWord; Throw: Boolean): Integer;
var tempRC: HGLRC;
    attributes : array [0..9] of LongWord;
begin
  try
    SetDCPixelFormat(DC, PF);
    tempRC := wglCreateContext(DC);
    if tempRC = 0 then
      RaiseLastOSError(GetLastError, 'Creating temporary render context fail.');
    if not wglMakeCurrent(DC, tempRC) then
      RaiseLastOSError(GetLastError, 'Selecting temporary render context fail.');

    InitializeWGL_ARB_create_context;
    if Addr(wglCreateContextAttribsARB) = nil then
      raise ENotImplemented.Create('Load wglCreateContextAttribsARB fail.');

    attributes[0]:= WGL_CONTEXT_MAJOR_VERSION_ARB;
    attributes[1]:= MajorVersion;
    attributes[2]:= WGL_CONTEXT_MINOR_VERSION_ARB;
    attributes[3]:= MinorVersion;
    attributes[4]:= WGL_CONTEXT_FLAGS_ARB;
    attributes[5]:= Flags;
    attributes[6]:= 0;{WGL_CONTEXT_PROFILE_MASK_ARB;
    attributes[7]:= ProfileMask;
    attributes[8]:= 0;}

    GLRC:= wglCreateContextAttribsARB(DC, 0, @attributes);
    if GLRC = 0 then
      RaiseLastOSError(GetLastError, 'Creating render context fail.');

    if not wglMakeCurrent(DC, GLRC) then begin
      wglDeleteContext(GLRC);
      GLRC:= 0;
      RaiseLastOSError(GetLastError, 'Selecting render context fail.');
    end;

  finally
    wglDeleteContext(tempRC);
  end;
end;

procedure TGLContext.DeleteContext(Throw: Boolean);
begin
  if not wglMakeCurrent(0, 0) and Throw then
    RaiseLastOSError;
  if not wglDeleteContext(GLRC) and Throw then
    RaiseLastOSError;
end;

procedure TGLContext.MakeCurrent(DC: HDC; Throw: Boolean);
begin
  if not wglMakeCurrent(DC, GLRC) and Throw then
    RaiseLastOSError;
end;

end.
