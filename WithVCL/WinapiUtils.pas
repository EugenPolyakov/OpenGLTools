unit WinapiUtils;

interface

uses SysTypes, System.SysUtils, Winapi.Windows, System.UITypes, VCL.Graphics;

type
  TFontData = record
  private
    FRecord: TAutoFinalizedRecord;
    FFont: TFont;
    function GetColor: TColor;
    procedure SetColor(const Value: TColor);
    function GetSize: Integer;
  public
    constructor Create(AFont: TFont); overload;
    constructor Create(const AFont: TFontData); overload;
    constructor Create(const FontName: string; Height: Integer; AStyle: TFontStyles; AQuality: TFontQuality); overload;
    property Color: TColor read GetColor write SetColor;
    property Size: Integer read GetSize;
    procedure Destroy;
    function GetHandle: HFONT;
    class operator Equal(const A, B: TFontData): Boolean; static;
  end;

  TBitmapGDI = record
  private
    FBitmap: TBitmap;
    function GetWidth: Integer; inline;
    function GetHeight: Integer; inline;
    procedure SetFont(const AFont: TFontData); inline;
  public
    procedure Initialize;
    procedure Destroy;
    procedure SetBound(AWidth, AHeight: Integer);
    function GetDC: HDC;
    procedure Clone(ADC: HDC); overload;
    procedure Clone(const bmp: TBitmapGDI); overload;
    procedure Lock;
    procedure Unlock;
    procedure TextOut(Str: PChar; X, Y: Integer);
    procedure SaveToFile(const FileName: string);
    function GetPixelsCount(OffsetY: Integer = 0): Integer;
    function GetGrayscalePixels(const Pixels: TArray<Byte>; OffsetY: Integer = 0): Integer;
    function IsInitialized: Boolean; inline;
    property Font: TFontData write SetFont;
    property Width: Integer read GetWidth;
    property Height: Integer read GetHeight;
  end;

implementation

{ TFontData }

constructor TFontData.Create(AFont: TFont);
begin
  FFont:= TFont.Create;
  FFont.Assign(AFont);
  FRecord.InitFinalizator(Destroy);
end;

constructor TFontData.Create(const FontName: string; Height: Integer;
  AStyle: TFontStyles; AQuality: TFontQuality);
begin
  FFont:= TFont.Create;
  FFont.Height:= Height;
  FFont.Style:= AStyle;
  FFont.Name:= FontName;
  FFont.Quality:= AQuality;
  FRecord.InitFinalizator(Destroy);
end;

constructor TFontData.Create(const AFont: TFontData);
begin
  Create(AFont.FFont);
end;

procedure TFontData.Destroy;
begin
  FRecord.ChangeFinalizator(nil); //на случай если вызвали руками, что бы не было задвоения
  FFont.Free;
end;

class operator TFontData.Equal(const A, B: TFontData): Boolean;
begin
  Result:= (A.FFont.Height     = B.FFont.Height) and
          (A.FFont.Orientation = B.FFont.Orientation) and
          (A.FFont.Pitch       = B.FFont.Pitch) and
          (A.FFont.Style       = B.FFont.Style) and
          (A.FFont.Charset     = B.FFont.Charset) and
          (A.FFont.Name        = B.FFont.Name) and
          (A.FFont.Quality     = B.FFont.Quality);
end;

function TFontData.GetColor: TColor;
begin
  Result:= FFont.Color;
end;

function TFontData.GetHandle: HFONT;
begin
  Result:= FFont.Handle;
end;

function TFontData.GetSize: Integer;
begin
  Result:= FFont.Size;
end;

procedure TFontData.SetColor(const Value: TColor);
begin
  FFont.Color:= Value;
end;

{ TBitmapGDI }

procedure TBitmapGDI.Clone(ADC: HDC);
begin

end;

procedure TBitmapGDI.Clone(const bmp: TBitmapGDI);
begin

end;

procedure TBitmapGDI.Destroy;
begin
  FreeAndNil(FBitmap);
end;

function TBitmapGDI.GetDC: HDC;
begin
  Result:= FBitmap.Canvas.Handle;
end;

function TBitmapGDI.GetHeight: Integer;
begin
  Result:= FBitmap.Height;
end;

function TBitmapGDI.GetGrayscalePixels(const Pixels: TArray<Byte>; OffsetY: Integer): Integer;
var bmi: TBitmapInfo;
    Error, I, J, ofsy: Integer;
    buf: array of Byte;
    hBmp : HBITMAP;
begin
  if FBitmap.Height <= OffsetY then
    Exit(0);

  FillChar(bmi, SizeOf(bmi), 0);
  bmi.bmiHeader.biSize:= SizeOf(TBitmapInfoHeader);
  bmi.bmiHeader.biBitCount:= 24;
  bmi.bmiHeader.biWidth:= FBitmap.Width;
  bmi.bmiHeader.biHeight:= FBitmap.Height;
  bmi.bmiHeader.biPlanes:= 1;
  bmi.bmiHeader.biCompression:= BI_RGB;
  Result:= GetPixelsCount(OffsetY);
  if Length(Pixels) < Result then
    raise EOutOfMemory.CreateFmt('Wrong buffer size. expected: %d, actual: %d',
        [Result, Length(Pixels)]);
  SetLength(buf, (bmi.bmiHeader.biWidth * 3 + 3) and -3);
  Lock;
  try
  for I := OffsetY to bmi.bmiHeader.biHeight - 1 do begin
    // Forces evaluation of Bitmap.Handle before Bitmap.Canvas.Handle
    hBmp:= FBitmap.Handle;
    Error:= GetDIBits(FBitmap.Canvas.Handle, hBmp, bmi.bmiHeader.biHeight - I - 1, 1, @buf[0], bmi, DIB_RGB_COLORS);
    if Error = 0 then
      RaiseLastOSError(GetLastError, ' TGrayBitmapGDI.GetPixels GetDIBits');
    ofsy:= (I - OffsetY) * bmi.bmiHeader.biWidth;
    for J := 0 to bmi.bmiHeader.biWidth - 1 do begin
      Pixels[ofsy + J]:= Round(buf[J * 3 + 0] * 0.2989 + buf[J * 3 + 1] * 0.5870 + buf[J * 3 + 2] * 0.1140);
    end;
  end;
  finally
    Unlock;
  end;
end;

function TBitmapGDI.GetPixelsCount(OffsetY: Integer): Integer;
begin
  Result:= FBitmap.Height - OffsetY;
  if Result < 0 then
    Result:= 0;
  Result:= Result * FBitmap.Width;
end;

function TBitmapGDI.GetWidth: Integer;
begin
  Result:= FBitmap.Width;
end;

procedure TBitmapGDI.Initialize;
begin
  FBitmap:= TBitmap.Create;
  FBitmap.PixelFormat:= pf24bit;
end;

function TBitmapGDI.IsInitialized: Boolean;
begin
  Result:= FBitmap <> nil;
end;

procedure TBitmapGDI.Lock;
begin
  FBitmap.Canvas.Lock;
end;

procedure TBitmapGDI.SaveToFile(const FileName: string);
begin
  FBitmap.SaveToFile(FileName);
end;

procedure TBitmapGDI.SetBound(AWidth, AHeight: Integer);
begin
  FBitmap.Canvas.Brush.Color:= clBlack;
  FBitmap.Canvas.Brush.Style:= bsSolid;
  FBitmap.SetSize(AWidth, AHeight);
  FBitmap.Canvas.Brush.Style:= bsClear;
end;

procedure TBitmapGDI.SetFont(const AFont: TFontData);
begin
  FBitmap.Canvas.Font.Assign(AFont.FFont);
end;

procedure TBitmapGDI.TextOut(Str: PChar; X, Y: Integer);
begin
  Winapi.Windows.ExtTextOut(FBitmap.Canvas.Handle, X, Y, 0{ETO_OPAQUE}, nil, Str,
      StrLen(Str), nil);
end;

procedure TBitmapGDI.Unlock;
begin
  FBitmap.Canvas.Unlock;
end;

end.
