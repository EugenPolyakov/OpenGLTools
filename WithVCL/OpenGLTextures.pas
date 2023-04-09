unit OpenGLTextures;

interface

uses System.SysUtils, WinApi.Windows, Vcl.Graphics, Vcl.Imaging.pngimage, Vcl.Imaging.GIFImg,
  Vcl.Imaging.jpeg, OpenGL, OpenGLUtils;

type
  TScanLine = procedure (Y: Integer; Data: Pointer) of object;
  TTexture2D = record
  private
    FValue: TGraphic;
    procedure Bitmap16ScanLine(Y: Integer; Data: Pointer);
    procedure Bitmap24ScanLine(Y: Integer; Data: Pointer);
    procedure Bitmap32ScanLine(Y: Integer; Data: Pointer);
    procedure Png24ScanLine(Y: Integer; Data: Pointer);
    procedure Png8ScanLine(Y: Integer; Data: Pointer);
    procedure Bitmap24TransparentScanLine(Y: Integer; Data: Pointer);
    procedure Bitmap32TransparentScanLine(Y: Integer; Data: Pointer);
    procedure PngRGBAScanLine(Y: Integer; Data: Pointer);
  public
    constructor CreateVCL(APicture: TPicture); overload;
    constructor CreateVCL(AGraphic: TGraphic); overload;
    class function IsSupported(APicture: TPicture): Boolean; overload; static;
    class function IsSupported(AGraphic: TGraphic): Boolean; overload; static;
    function Generate(ATarget: {$IFDEF OGL_USE_ENUMS}TTextureTarget{$ELSE}GLenum{$ENDIF}
        = {$IFDEF OGL_USE_ENUMS}TTextureTarget.{$ENDIF}GL_TEXTURE_2D): TOGLTexture;
    class procedure GenerateTexture(internalFormat: {$IFDEF OGL_USE_ENUMS}TInternalFormat{$ELSE}GLint{$ENDIF};
        pixelFormat: {$IFDEF OGL_USE_ENUMS}TPixelFormat{$ELSE}GLenum{$ENDIF};
        pixelType: {$IFDEF OGL_USE_ENUMS}TPixelType{$ELSE}GLenum{$ENDIF};
        ScanLine: TScanLine; AWidth, AHeight, LineSize: Integer; ProcessByLine: Boolean;
        ATarget: {$IFDEF OGL_USE_ENUMS}TTextureTarget{$ELSE}GLenum{$ENDIF}= {$IFDEF OGL_USE_ENUMS}TTextureTarget.{$ENDIF}GL_TEXTURE_2D); static;
  end;

  TBitmapHelper = class helper for TBitmap
    function IsVerticalReverse: Boolean; inline;
  end;

  TBitmapImageHelper = class helper for TBitmapImage
    function GetDIB: PDIBSection; inline;
  end;

implementation

uses
  SysUtilsExtensions;

type
  TJPEGImageProtected = class (TJPEGImage)
  end;

{ TTexture2D }

constructor TTexture2D.CreateVCL(APicture: TPicture);
begin
  CreateVCL(APicture.Graphic);
end;

procedure TTexture2D.Bitmap16ScanLine(Y: Integer; Data: Pointer);
begin
  Move(TBitmap(FValue).ScanLine[Y]^, Data^, 2 * FValue.Width);
end;

procedure TTexture2D.Bitmap24ScanLine(Y: Integer; Data: Pointer);
begin
  Move(TBitmap(FValue).ScanLine[Y]^, Data^, 3 * FValue.Width);
end;

procedure TTexture2D.Bitmap24TransparentScanLine(Y: Integer; Data: Pointer);
var alpha: TColor;
    j: Integer;
begin
  Move(TBitmap(FValue).ScanLine[Y]^, Data^, 3 * FValue.Width);
  alpha:= TBitmap(FValue).TransparentColor shl 8;
  SwapAny(alpha, 4);
  for j := FValue.Width - 1 downto 0 do begin
    Move(Pointer(Integer(Data) + j * 3)^, Pointer(Integer(Data) + j * 4)^, 3);
    if CompareMem(Pointer(Integer(Data) + j * 4), @alpha, 3) then
      PByte(Integer(Data) + j * 4 + 3)^:= 0
    else
      PByte(Integer(Data) + j * 4 + 3)^:= $FF;
  end;
end;

procedure TTexture2D.Bitmap32ScanLine(Y: Integer; Data: Pointer);
begin
  Move(TBitmap(FValue).ScanLine[Y]^, Data^, 4 * FValue.Width);
end;

procedure TTexture2D.Bitmap32TransparentScanLine(Y: Integer; Data: Pointer);
var alpha: TColor;
    j: Integer;
begin
  Move(TBitmap(FValue).ScanLine[Y]^, Data^, 4 * FValue.Width);
  alpha:= TBitmap(FValue).TransparentColor shl 8;
  SwapAny(alpha, 4);
  for j := 0 to FValue.Width - 1 do begin
    if CompareMem(Pointer(Integer(Data) + j * 4), @alpha, 3) then
      PByte(Integer(Data) + j * 4 + 3)^:= 0
    else
      PByte(Integer(Data) + j * 4 + 3)^:= $FF;
  end;
end;

constructor TTexture2D.CreateVCL(AGraphic: TGraphic);
begin
  if AGraphic is TJPEGImage then
    FValue:= TJPEGImageProtected(AGraphic).Bitmap
  else if AGraphic is TGIFImage then
    FValue:= TGIFImage(AGraphic).Bitmap
  else
    FValue:= AGraphic;
end;

function TTexture2D.Generate(ATarget: {$IFDEF OGL_USE_ENUMS}TTextureTarget{$ELSE}GLenum{$ENDIF}): TOGLTexture;
var internalFormat: {$IFDEF OGL_USE_ENUMS}TInternalFormat{$ELSE}GLint{$ENDIF};
    pixelFormat: {$IFDEF OGL_USE_ENUMS}TPixelFormat{$ELSE}GLenum{$ENDIF};
    pixelType: {$IFDEF OGL_USE_ENUMS}TPixelType{$ELSE}GLenum{$ENDIF};
    ProcessByLine: Boolean;
    lineSize: Integer;
    scaner: TScanLine;
begin
  glGenTextures(1, @Result.Texture);
  Result.Target:= ATarget;
  Result.Enable;
  Result.Bind;
  if FValue is TBitmap then begin
    ProcessByLine:= TBitmap(FValue).IsVerticalReverse or TBitmap(FValue).Transparent;
    case TBitmap(FValue).PixelFormat of
      pf24bit: begin
        if TBitmap(FValue).Transparent then begin
          internalFormat:= {$IFDEF OGL_USE_ENUMS}TInternalFormat.{$ENDIF}GL_RGBA;
          pixelFormat:= {$IFDEF OGL_USE_ENUMS}TPixelFormat.{$ENDIF}GL_BGRA;
          lineSize:= 4 * FValue.Width;
          scaner:= Bitmap24TransparentScanLine;
        end else begin
          internalFormat:= {$IFDEF OGL_USE_ENUMS}TInternalFormat.{$ENDIF}GL_RGB;
          pixelFormat:= {$IFDEF OGL_USE_ENUMS}TPixelFormat.{$ENDIF}GL_BGR;
          lineSize:= 3 * FValue.Width;
          scaner:= Bitmap24ScanLine;
        end;
        pixelType:= {$IFDEF OGL_USE_ENUMS}TPixelType.{$ENDIF}GL_UNSIGNED_BYTE;
      end;
      pf32bit: begin
        if (TBitmap(FValue).AlphaFormat = afDefined) or TBitmap(FValue).Transparent then
          internalFormat:= {$IFDEF OGL_USE_ENUMS}TInternalFormat.{$ENDIF}GL_RGBA
        else
          internalFormat:= {$IFDEF OGL_USE_ENUMS}TInternalFormat.{$ENDIF}GL_RGB;
        lineSize:= 4 * FValue.Width;
        pixelFormat:= {$IFDEF OGL_USE_ENUMS}TPixelFormat.{$ENDIF}GL_BGRA;
        pixelType:= {$IFDEF OGL_USE_ENUMS}TPixelType.{$ENDIF}GL_UNSIGNED_BYTE;
        if TBitmap(FValue).Transparent then
          scaner:= Bitmap32TransparentScanLine
        else
          scaner:= Bitmap32ScanLine;
      end;
      pf15bit: begin
        internalFormat:= {$IFDEF OGL_USE_ENUMS}TInternalFormat.{$ENDIF}GL_RGB;
        pixelFormat:= {$IFDEF OGL_USE_ENUMS}TPixelFormat.{$ENDIF}GL_RGB;
        pixelType:= {$IFDEF OGL_USE_ENUMS}TPixelType.{$ENDIF}GL_UNSIGNED_SHORT_1_5_5_5_REV;
        lineSize:= 2 * FValue.Width;
        scaner:= Bitmap16ScanLine;
        if TBitmap(FValue).Transparent then
          raise Exception.Create('Unsupported pixel format 15Transparent');
      end;
      pf16bit: begin
        internalFormat:= {$IFDEF OGL_USE_ENUMS}TInternalFormat.{$ENDIF}GL_RGB;
        pixelFormat:= {$IFDEF OGL_USE_ENUMS}TPixelFormat.{$ENDIF}GL_RGB;
        pixelType:= {$IFDEF OGL_USE_ENUMS}TPixelType.{$ENDIF}GL_UNSIGNED_SHORT_5_6_5;
        lineSize:= 2 * FValue.Width;
        scaner:= Bitmap16ScanLine;
        if TBitmap(FValue).Transparent then
          raise Exception.Create('Unsupported pixel format 16Transparent');
      end;
      {pfDevice,
      pf1bit,
      pf4bit,
      pf8bit,
      pfCustom}
    else
      raise Exception.Create('Unsupported pixel format');
    end;
  end else if FValue is TPngImage then begin
    ProcessByLine:= True;
    case TPngImage(FValue).Header.ColorType of
      COLOR_RGB: begin
        internalFormat:= {$IFDEF OGL_USE_ENUMS}TInternalFormat.{$ENDIF}GL_RGB;
        pixelFormat:= {$IFDEF OGL_USE_ENUMS}TPixelFormat.{$ENDIF}GL_BGR;
        pixelType:= {$IFDEF OGL_USE_ENUMS}TPixelType.{$ENDIF}GL_UNSIGNED_BYTE;
        lineSize:= 3 * FValue.Width;
        scaner:= Png24ScanLine;
      end;
      COLOR_GRAYSCALE: begin
        internalFormat:= {$IFDEF OGL_USE_ENUMS}TInternalFormat.{$ENDIF}GL_RED;
        pixelFormat:= {$IFDEF OGL_USE_ENUMS}TPixelFormat.{$ENDIF}GL_RED;
        pixelType:= {$IFDEF OGL_USE_ENUMS}TPixelType.{$ENDIF}GL_UNSIGNED_BYTE;
        lineSize:= FValue.Width;
        scaner:= Png8ScanLine;
      end;
      COLOR_RGBALPHA: begin
        internalFormat:= {$IFDEF OGL_USE_ENUMS}TInternalFormat.{$ENDIF}GL_RGBA;
        pixelFormat:= {$IFDEF OGL_USE_ENUMS}TPixelFormat.{$ENDIF}GL_BGRA;
        pixelType:= {$IFDEF OGL_USE_ENUMS}TPixelType.{$ENDIF}GL_UNSIGNED_BYTE;
        lineSize:= 4 * FValue.Width;
        scaner:= PngRGBAScanLine;
      end;
      //COLOR_PALETTE;
      //COLOR_GRAYSCALEALPHA = 4;
    else
      raise Exception.Create('Unsupported pixel format');
    end;
  end else
    raise Exception.Create('Unsupported image format');

  if ATarget <> {$IFDEF OGL_USE_ENUMS}TTextureTarget.{$ENDIF}GL_TEXTURE_2D then begin
    glTexParameteri(ATarget, {$IFDEF OGL_USE_ENUMS}TTextureParameterName.{$ENDIF}GL_TEXTURE_BASE_LEVEL, 0);
    glTexParameteri(ATarget, {$IFDEF OGL_USE_ENUMS}TTextureParameterName.{$ENDIF}GL_TEXTURE_MAX_LEVEL, 0);
    glTexParameteri(ATarget, {$IFDEF OGL_USE_ENUMS}TTextureParameterName.{$ENDIF}GL_TEXTURE_MIN_FILTER, GLint({$IFDEF OGL_USE_ENUMS}TTextureMinFilter.{$ENDIF}GL_LINEAR));
    glTexParameteri(ATarget, {$IFDEF OGL_USE_ENUMS}TTextureParameterName.{$ENDIF}GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(ATarget, {$IFDEF OGL_USE_ENUMS}TTextureParameterName.{$ENDIF}GL_TEXTURE_WRAP_T, GL_CLAMP);
  end else begin
    glTexParameteri(ATarget, {$IFDEF OGL_USE_ENUMS}TTextureParameterName.{$ENDIF}GL_GENERATE_MIPMAP, GLint(True));
    glTexParameteri(ATarget, {$IFDEF OGL_USE_ENUMS}TTextureParameterName.{$ENDIF}GL_TEXTURE_MIN_FILTER, GLint({$IFDEF OGL_USE_ENUMS}TTextureMinFilter.{$ENDIF}GL_LINEAR_MIPMAP_LINEAR));
    glTexParameteri(ATarget, {$IFDEF OGL_USE_ENUMS}TTextureParameterName.{$ENDIF}GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(ATarget, {$IFDEF OGL_USE_ENUMS}TTextureParameterName.{$ENDIF}GL_TEXTURE_WRAP_T, GL_REPEAT);
  end;

  glTexParameteri(ATarget, {$IFDEF OGL_USE_ENUMS}TTextureParameterName.{$ENDIF}GL_TEXTURE_MAG_FILTER, GLint({$IFDEF OGL_USE_ENUMS}TTextureMagFilter.{$ENDIF}GL_LINEAR));

  GenerateTexture(internalFormat, pixelFormat, pixelType, scaner,
      FValue.Width, FValue.Height, lineSize, ProcessByLine,
      ATarget);
end;

class procedure TTexture2D.GenerateTexture(internalFormat: {$IFDEF OGL_USE_ENUMS}TInternalFormat{$ELSE}GLint{$ENDIF};
  pixelFormat: {$IFDEF OGL_USE_ENUMS}TPixelFormat{$ELSE}GLenum{$ENDIF};
  pixelType: {$IFDEF OGL_USE_ENUMS}TPixelType{$ELSE}GLenum{$ENDIF}; ScanLine: TScanLine; AWidth, AHeight, LineSize: Integer;
  ProcessByLine: Boolean; ATarget: {$IFDEF OGL_USE_ENUMS}TTextureTarget{$ELSE}GLenum{$ENDIF});
var i: Integer;
    full: array of Byte;
begin
  glPixelStorei({$IFDEF OGL_USE_ENUMS}TPixelStoreParameter.{$ENDIF}GL_UNPACK_ALIGNMENT, 1);
  SetLength(full, LineSize * AHeight);
  for i := 0 to AHeight - 1 do
    ScanLine(i, @full[LineSize * i]);
  glTexImage2D(ATarget, 0, internalFormat, AWidth, AHeight, 0,
    pixelFormat, pixelType, @full[0]);
end;

class function TTexture2D.IsSupported(APicture: TPicture): Boolean;
begin
  Result:= IsSupported(APicture.Graphic);
end;

class function TTexture2D.IsSupported(AGraphic: TGraphic): Boolean;
begin
  if AGraphic is TJPEGImage then
    AGraphic:= TJPEGImageProtected(AGraphic).Bitmap
  else if AGraphic is TGIFImage then
    AGraphic:= TGIFImage(AGraphic).Bitmap;
  if AGraphic is TBitmap then
    case TBitmap(AGraphic).PixelFormat of
      pf24bit, pf32bit, pf15bit, pf16bit: Result:= True;
    else
      Result:= False;
    end
  else if AGraphic is TPngImage then
    case TPngImage(AGraphic).Header.ColorType of
      COLOR_RGB, COLOR_GRAYSCALE, COLOR_RGBALPHA: Result:= True;
    else
      Result:= False;
    end
  else
    Result:= False;
end;

procedure TTexture2D.Png24ScanLine(Y: Integer; Data: Pointer);
begin
  Move(TPngImage(FValue).ScanLine[Y]^, Data^, 3 * FValue.Width);
end;

procedure TTexture2D.Png8ScanLine(Y: Integer; Data: Pointer);
begin
  Move(TPngImage(FValue).ScanLine[Y]^, Data^, FValue.Width);
end;

procedure TTexture2D.PngRGBAScanLine(Y: Integer; Data: Pointer);
var alpha: pByteArray;
    j: Integer;
begin
  Move(TPngImage(FValue).ScanLine[Y]^, Data^, 3 * FValue.Width);
  alpha:= TPngImage(FValue).AlphaScanline[Y];
  for j := FValue.Width - 1 downto 0 do begin
    PByte(Integer(Data) + j * 4 + 3)^:= alpha[j];
    Move(PByte(Integer(Data) + j * 3)^, PByte(Integer(Data) + j * 4)^, 3);
  end;
end;

{ TBitmapHelper }

function TBitmapHelper.IsVerticalReverse: Boolean;
begin
  Result:= Self.FImage.GetDIB.dsBmih.biHeight > 0;
end;

{ TBitmapImageHelper }

function TBitmapImageHelper.GetDIB: PDIBSection;
begin
  Result:= @Self.FDIB;
end;

end.
