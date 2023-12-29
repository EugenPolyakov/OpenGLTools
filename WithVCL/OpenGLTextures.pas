unit OpenGLTextures;

interface

uses System.SysUtils, WinApi.Windows, Vcl.Graphics, Vcl.Imaging.pngimage, Vcl.Imaging.GIFImg,
  Vcl.Imaging.jpeg, OpenGL, OpenGLUtils;

type
  TScanLine = procedure (AGraphic: TGraphic; Y, Offset, Width: Integer; Data: Pointer);

  TTextureParameters = record
    internalFormat: {$IFDEF OGL_USE_ENUMS}TInternalFormat{$ELSE}GLint{$ENDIF};
    pixelFormat: {$IFDEF OGL_USE_ENUMS}TPixelFormat{$ELSE}GLenum{$ENDIF};
    pixelType: {$IFDEF OGL_USE_ENUMS}TPixelType{$ELSE}GLenum{$ENDIF};
    pixelSize: Integer;
    scaner: TScanLine;
  end;

  TTexture2D = record
  private
    FValue: TGraphic;
    class procedure Bitmap16ScanLine(AGraphic: TGraphic; Y, Offset, Width: Integer; Data: Pointer); static;
    class procedure Bitmap24ScanLine(AGraphic: TGraphic; Y, Offset, Width: Integer; Data: Pointer); static;
    class procedure Bitmap32ScanLine(AGraphic: TGraphic; Y, Offset, Width: Integer; Data: Pointer); static;
    class procedure Png24ScanLine(AGraphic: TGraphic; Y, Offset, Width: Integer; Data: Pointer); static;
    class procedure Png8ScanLine(AGraphic: TGraphic; Y, Offset, Width: Integer; Data: Pointer); static;
    class procedure Bitmap24TransparentScanLine(AGraphic: TGraphic; Y, Offset, Width: Integer; Data: Pointer); static;
    class procedure Bitmap32TransparentScanLine(AGraphic: TGraphic; Y, Offset, Width: Integer; Data: Pointer); static;
    class procedure PngRGBAScanLine(AGraphic: TGraphic; Y, Offset, Width: Integer; Data: Pointer); static;
  public
    property Graphic: TGraphic read FValue;
    constructor CreateVCL(APicture: TPicture); overload;
    constructor CreateVCL(AGraphic: TGraphic); overload;
    class function IsSupported(APicture: TPicture): Boolean; overload; static;
    class function IsSupported(AGraphic: TGraphic): Boolean; overload; static;
    function Generate(ATarget: {$IFDEF OGL_USE_ENUMS}TTextureTarget{$ELSE}GLenum{$ENDIF}
        = {$IFDEF OGL_USE_ENUMS}TTextureTarget.{$ENDIF}GL_TEXTURE_2D): TOGLTexture;
    function GenerateParameters: TTextureParameters;
    class procedure GenerateTexture(AGraphic: TGraphic; const AParams: TTextureParameters; AWidth, AHeight: Integer;
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

class procedure TTexture2D.Bitmap16ScanLine(AGraphic: TGraphic; Y, Offset, Width: Integer; Data: Pointer);
begin
  Move(PAnsiChar(TBitmap(AGraphic).ScanLine[Y])[Offset * 2], Data^, 2 * Width);
end;

class procedure TTexture2D.Bitmap24ScanLine(AGraphic: TGraphic; Y, Offset, Width: Integer; Data: Pointer);
begin
  Move(PAnsiChar(TBitmap(AGraphic).ScanLine[Y])[Offset * 3], Data^, 3 * Width);
end;

class procedure TTexture2D.Bitmap24TransparentScanLine(AGraphic: TGraphic; Y, Offset, Width: Integer; Data: Pointer);
var alpha: TColor;
    j: Integer;
    Bytes: PByte absolute Data;
begin
  Move(PAnsiChar(TBitmap(AGraphic).ScanLine[Y])[Offset * 3], Data^, 3 * Width);
  alpha:= TBitmap(AGraphic).TransparentColor shl 8;
  SwapAny(alpha, 4);
  for j := Width - 1 downto 0 do begin
    Move(Bytes[j * 3], Bytes[j * 4], 3);
    if CompareMem(Pointer(NativeUInt(Data) + j * 4), @alpha, 3) then
      Bytes[j * 4 + 3]:= 0
    else
      Bytes[j * 4 + 3]:= $FF;
  end;
end;

class procedure TTexture2D.Bitmap32ScanLine(AGraphic: TGraphic; Y, Offset, Width: Integer; Data: Pointer);
begin
  Move(PAnsiChar(TBitmap(AGraphic).ScanLine[Y])[Offset * 4], Data^, 4 * Width);
end;

class procedure TTexture2D.Bitmap32TransparentScanLine(AGraphic: TGraphic; Y, Offset, Width: Integer; Data: Pointer);
var alpha: TColor;
    j: Integer;
    Bytes: PByte absolute Data;
begin
  Move(PAnsiChar(TBitmap(AGraphic).ScanLine[Y])[Offset * 4], Data^, 4 * Width);
  alpha:= TBitmap(AGraphic).TransparentColor shl 8;
  SwapAny(alpha, 4);
  for j := 0 to Width - 1 do begin
    if CompareMem(@Bytes[j * 4], @alpha, 3) then
      Bytes[j * 4 + 3]:= 0
    else
      Bytes[j * 4 + 3]:= $FF;
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
var params: TTextureParameters;
begin
  glGenTextures(1, @Result.Texture);
  Result.Target:= ATarget;
  Result.Enable;
  Result.Bind;

  params:= GenerateParameters;

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

  GenerateTexture(FValue, params, FValue.Width, FValue.Height, ATarget);
end;

function TTexture2D.GenerateParameters: TTextureParameters;
begin
  if FValue is TBitmap then begin
    case TBitmap(FValue).PixelFormat of
      pf24bit: begin
        if TBitmap(FValue).Transparent then begin
          Result.internalFormat:= {$IFDEF OGL_USE_ENUMS}TInternalFormat.{$ENDIF}GL_RGBA;
          Result.pixelFormat:= {$IFDEF OGL_USE_ENUMS}TPixelFormat.{$ENDIF}GL_BGRA;
          Result.pixelSize:= 4;
          Result.scaner:= Bitmap24TransparentScanLine;
        end else begin
          Result.internalFormat:= {$IFDEF OGL_USE_ENUMS}TInternalFormat.{$ENDIF}GL_RGB;
          Result.pixelFormat:= {$IFDEF OGL_USE_ENUMS}TPixelFormat.{$ENDIF}GL_BGR;
          Result.pixelSize:= 3;
          Result.scaner:= Bitmap24ScanLine;
        end;
        Result.pixelType:= {$IFDEF OGL_USE_ENUMS}TPixelType.{$ENDIF}GL_UNSIGNED_BYTE;
      end;
      pf32bit: begin
        if (TBitmap(FValue).AlphaFormat = afDefined) or TBitmap(FValue).Transparent then
          Result.internalFormat:= {$IFDEF OGL_USE_ENUMS}TInternalFormat.{$ENDIF}GL_RGBA
        else
          Result.internalFormat:= {$IFDEF OGL_USE_ENUMS}TInternalFormat.{$ENDIF}GL_RGB;
        Result.pixelSize:= 4;
        Result.pixelFormat:= {$IFDEF OGL_USE_ENUMS}TPixelFormat.{$ENDIF}GL_BGRA;
        Result.pixelType:= {$IFDEF OGL_USE_ENUMS}TPixelType.{$ENDIF}GL_UNSIGNED_BYTE;
        if TBitmap(FValue).Transparent then
          Result.scaner:= Bitmap32TransparentScanLine
        else
          Result.scaner:= Bitmap32ScanLine;
      end;
      pf15bit: begin
        Result.internalFormat:= {$IFDEF OGL_USE_ENUMS}TInternalFormat.{$ENDIF}GL_RGB;
        Result.pixelFormat:= {$IFDEF OGL_USE_ENUMS}TPixelFormat.{$ENDIF}GL_RGB;
        Result.pixelType:= {$IFDEF OGL_USE_ENUMS}TPixelType.{$ENDIF}GL_UNSIGNED_SHORT_1_5_5_5_REV;
        Result.pixelSize:= 2;
        Result.scaner:= Bitmap16ScanLine;
        if TBitmap(FValue).Transparent then
          raise Exception.Create('Unsupported pixel format 15Transparent');
      end;
      pf16bit: begin
        Result.internalFormat:= {$IFDEF OGL_USE_ENUMS}TInternalFormat.{$ENDIF}GL_RGB;
        Result.pixelFormat:= {$IFDEF OGL_USE_ENUMS}TPixelFormat.{$ENDIF}GL_RGB;
        Result.pixelType:= {$IFDEF OGL_USE_ENUMS}TPixelType.{$ENDIF}GL_UNSIGNED_SHORT_5_6_5;
        Result.pixelSize:= 2;
        Result.scaner:= Bitmap16ScanLine;
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
    case TPngImage(FValue).Header.ColorType of
      COLOR_RGB: begin
        Result.internalFormat:= {$IFDEF OGL_USE_ENUMS}TInternalFormat.{$ENDIF}GL_RGB;
        Result.pixelFormat:= {$IFDEF OGL_USE_ENUMS}TPixelFormat.{$ENDIF}GL_BGR;
        Result.pixelType:= {$IFDEF OGL_USE_ENUMS}TPixelType.{$ENDIF}GL_UNSIGNED_BYTE;
        Result.pixelSize:= 3;
        Result.scaner:= Png24ScanLine;
      end;
      COLOR_GRAYSCALE: begin
        Result.internalFormat:= {$IFDEF OGL_USE_ENUMS}TInternalFormat.{$ENDIF}GL_RED;
        Result.pixelFormat:= {$IFDEF OGL_USE_ENUMS}TPixelFormat.{$ENDIF}GL_RED;
        Result.pixelType:= {$IFDEF OGL_USE_ENUMS}TPixelType.{$ENDIF}GL_UNSIGNED_BYTE;
        Result.pixelSize:= 1;
        Result.scaner:= Png8ScanLine;
      end;
      COLOR_RGBALPHA: begin
        Result.internalFormat:= {$IFDEF OGL_USE_ENUMS}TInternalFormat.{$ENDIF}GL_RGBA;
        Result.pixelFormat:= {$IFDEF OGL_USE_ENUMS}TPixelFormat.{$ENDIF}GL_BGRA;
        Result.pixelType:= {$IFDEF OGL_USE_ENUMS}TPixelType.{$ENDIF}GL_UNSIGNED_BYTE;
        Result.pixelSize:= 4;
        Result.scaner:= PngRGBAScanLine;
      end;
      //COLOR_PALETTE;
      //COLOR_GRAYSCALEALPHA = 4;
    else
      raise Exception.Create('Unsupported pixel format');
    end;
  end else
    raise Exception.Create('Unsupported image format');
end;

class procedure TTexture2D.GenerateTexture(AGraphic: TGraphic; const AParams: TTextureParameters; AWidth, AHeight: Integer;
  ATarget: {$IFDEF OGL_USE_ENUMS}TTextureTarget{$ELSE}GLenum{$ENDIF});
var i: Integer;
    full: array of Byte;
begin
  glPixelStorei({$IFDEF OGL_USE_ENUMS}TPixelStoreParameter.{$ENDIF}GL_UNPACK_ALIGNMENT, 1);
  SetLength(full, AParams.pixelSize * AWidth * AHeight);
  for i := 0 to AHeight - 1 do
    AParams.scaner(AGraphic, i, 0, AWidth, @full[AParams.pixelSize * i * AWidth]);
  glTexImage2D(ATarget, 0, AParams.internalFormat, AWidth, AHeight, 0,
    AParams.pixelFormat, AParams.pixelType, @full[0]);
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

class procedure TTexture2D.Png24ScanLine(AGraphic: TGraphic; Y, Offset, Width: Integer; Data: Pointer);
begin
  Move(PAnsiChar(TPngImage(AGraphic).ScanLine[Y])[Offset * 3], Data^, 3 * Width);
end;

class procedure TTexture2D.Png8ScanLine(AGraphic: TGraphic; Y, Offset, Width: Integer; Data: Pointer);
begin
  Move(PAnsiChar(TPngImage(AGraphic).ScanLine[Y])[Offset], Data^, Width);
end;

class procedure TTexture2D.PngRGBAScanLine(AGraphic: TGraphic; Y, Offset, Width: Integer; Data: Pointer);
var alpha: pByteArray;
    j: Integer;
    Bytes: PByte absolute Data;
begin
  Move(PAnsiChar(TPngImage(AGraphic).ScanLine[Y])[Offset * 3], Data^, 3 * Width);
  alpha:= TPngImage(AGraphic).AlphaScanline[Y];
  for j := Width - 1 downto 0 do begin
    Bytes[j * 4 + 3]:= alpha[j + Offset];
    Move(Bytes[j * 3], Bytes[j * 4], 3);
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
