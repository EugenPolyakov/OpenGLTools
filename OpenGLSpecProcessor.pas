unit OpenGLSpecProcessor;

interface

uses System.SysUtils, System.StrUtils, System.Classes, System.Generics.Collections, FastXML,
  SysTypes, StreamExtensions, RecordUtils;

type
  TCommandUsing = (cuNone, cuStatic, cuDynamic);
  PCommandUsing = ^TCommandUsing;

  TEnum = record
    Name: string;
    Value: string;
    Comment: string;
    Alias: string;
    Group: string;
  end;
  PEnum = ^TEnum;

  TEnumGroup = record
    GroupName: string;
    Comment: string;
    Enums: TArray<string>;
    IsSet: Boolean;
  end;

  TRequirements = record
    Supported: string;
    Enums: TArray<string>;
    Commands: TArray<string>;
    Comment: string;
  end;

  TType = record
    Name: string;
    FullText: string;
    IsApientry: Boolean;
    RequiredType: string;
  end;

  TParam = record
    Name: string;
    InType: string;
    FullText: string;
    Length: string;
    Group: string;
  end;

  TCommand = record
    Name: TParam;
    Params: TArray<TParam>;
    Aliases: TArray<string>;
  end;

  TOGLExtension = record
    Name: string;
    Supported: TArray<string>;
    Require: TArray<TRequirements>;
    Remove: TArray<TRequirements>;
    IsFeature: Boolean;
  end;
  POGLExtension = ^TOGLExtension;

  TParsedData = record
    Types: TArray<TType>;
    Enums: TArray<TEnum>;
    Commands: TArray<TCommand>;
    EnumGroups: TArray<TEnumGroup>;
    Extensions: TArray<TOGLExtension>;
    function IndexOfCommand(const Name: string): Integer;
    function IndexOfEnum(const Name: string): Integer;
    function IndexOfEnumGroup(const Name: string): Integer;
    function IndexOfType(const Name: string): Integer;
  end;

  TGeneratorOptions = record
    UnitName: string;
    AdditionalUses: string;
    ConvertPointersToArray: Boolean;
    UseEnumeratesAndSets: Boolean;
    GenerateDefaultCFunctions: Boolean;
    AddGetProcAddress: Boolean;
    UnicodePascal: Boolean;
    CustomForcedSets: TArray<string>;
    CustomExcludedSets: TArray<string>;
    Profile: string;
    Selection: TArray<TArray<TCommandUsing>>;
    function IsSetExcluded(const Name: string): Boolean;
  end;

  TOGLLoader = class;

  TCommandsReader = record
    Current: TCommand;
    CurrentParam: TParam;
    Owner: TOGLLoader;
    function NewElement(const ElementName: string; ParseOptions: PXMLElementParserOptions; Root: Pointer): Pointer;
    procedure NewAttribute(const AttributeName, AttributeValue: string; Element: Pointer);
    procedure NewText(const Value: string; Element: Pointer);
    procedure CloseElement(Element: Pointer);
    procedure InitOptions(ParseOptions: PXMLElementParserOptions);
  end;

  TEnumReader = record
    Group: TEnumGroup;
    CurrentGroupIndex: Integer;
    Enum: TEnum;
    Owner: TOGLLoader;
    procedure InsertEnumInGroup(const GroupName: string); overload;
    procedure InsertEnumInGroup(GroupIndex: Integer); overload;
    procedure EnumNewAttribute(const AttributeName, AttributeValue: string; Element: Pointer);
    procedure CloseEnum(Element: Pointer);
    function NewElement(const ElementName: string; ParseOptions: PXMLElementParserOptions; Root: Pointer): Pointer;
    function GroupsNewElement(const ElementName: string; ParseOptions: PXMLElementParserOptions; Root: Pointer): Pointer;
    procedure GroupNewAttribute(const AttributeName, AttributeValue: string; Element: Pointer);
    procedure EnumsNewAttribute(const AttributeName, AttributeValue: string; Element: Pointer);
    procedure CloseParentElement(Element: Pointer);
    procedure InitGroupsOptions(ParseOptions: PXMLElementParserOptions);
    procedure InitEnumsOptions(ParseOptions: PXMLElementParserOptions);
  end;

  TExtensionReader = record
    Current: TOGLExtension;
    CurrentRequire: TRequirements;
    Owner: TOGLLoader;
    function NewExtensionElement(const ElementName: string; ParseOptions: PXMLElementParserOptions; Root: Pointer): Pointer;
    function NewElement(const ElementName: string; ParseOptions: PXMLElementParserOptions; Root: Pointer): Pointer;
    function NewRequireElement(const ElementName: string; ParseOptions: PXMLElementParserOptions; Root: Pointer): Pointer;
    procedure NewFeatureAttribute(const AttributeName, AttributeValue: string; Element: Pointer);
    procedure NewExtensionAttribute(const AttributeName, AttributeValue: string; Element: Pointer);
    procedure NewRequireAttribute(const AttributeName, AttributeValue: string; Element: Pointer);
    procedure CloseElement(Element: Pointer);
    procedure CloseRequirementElement(Element: Pointer);
    procedure InitFeatureOptions(ParseOptions: PXMLElementParserOptions);
    procedure InitExtensionsOptions(ParseOptions: PXMLElementParserOptions);
  end;

  TTypesReader = record
    Current: TType;
    Owner: TOGLLoader;
    function NewElement(const ElementName: string; ParseOptions: PXMLElementParserOptions; Root: Pointer): Pointer;
    function NewElementLikeAttribute(const ElementName: string; ParseOptions: PXMLElementParserOptions; Root: Pointer): Pointer;
    procedure NewAttribute(const AttributeName, AttributeValue: string; Element: Pointer);
    procedure NewText(const Value: string; Element: Pointer);
    procedure NewTextName(const Value: string; Element: Pointer);
    procedure CloseElement(Element: Pointer);
    procedure InitOptions(ParseOptions: PXMLElementParserOptions);
  end;

  TOGLLoader = class
  private
    EnumReader: TEnumReader;
    ExtensionReader: TExtensionReader;
    TypesReader: TTypesReader;
    CommadsReader: TCommandsReader;
  public
    Data: TParsedData;
    function NewElement(const ElementName: string; ParseOptions: PXMLElementParserOptions; Root: Pointer): Pointer;
    constructor Create;
    destructor Destroy; override;
  end;

  TAPData = record
    PointerCount: Integer;
    ArraySpecific: TArray<Integer>;
    constructor Create(APointerCount: Integer; const ASpec: array of Integer);
    class operator Equal(const A, B: TAPData): Boolean;
    class operator NotEqual(const A, B: TAPData): Boolean;
    function GetNameSuffix: AnsiString;
    function GetNamePrefix: AnsiString;
    function GenerateName(N: AnsiString): AnsiString;
    function GetArrayTypeDef: AnsiString;
  end;

  TTypeExportInfo = record
    Using: array of Boolean;
    //MaxPointerLevel: array of Byte;
    ExtendedArrays: TDictionary<Integer, TArray<TArray<TAPData>>>;
    procedure AddAP(Index: Integer; const AP: array of TAPData);
    procedure Finalize(UseDefault: Boolean);
  end;

  TCommandInfo = record
    CommandUsing: TCommandUsing;
    ResultType: AnsiString;
    ResultDelphiType: AnsiString;
    Params: TArray<AnsiString>;
  end;

  TSelectionInfo = record
    TypesInfo, EnumGroups: TTypeExportInfo;
    PointerLevel,
    CurrentData,
    groupsOffset,
    typesOffset,
    enumsOffset,
    commandsOffset: Integer;
    neededEnums: array of Boolean;
    EnumsInGroup: array of Boolean;
    enumIndexes: TDictionary<Integer, TArray<Integer>>;
    skipedEnumIndexes: TDictionary<Integer, TArray<string>>;
    extendedTypeNames: TDictionary<Integer, AnsiString>;
    neededCommands: array of TCommandInfo;
    procedure Finalize(UseDefault: Boolean);
    procedure ResetOffset;
    procedure UpdateOffset(const AData: TParsedData);
  end;

  TCTypeConverter = class;

  TPascalSaver = class
  private
    FConverter: TCTypeConverter;
  protected
    LoadedData: TArray<TParsedData>;
    OutStream: TStream;
    Prepared: TSelectionInfo;
    function GetPointerLevel(const typeDefine: string): Integer;
    function IsPointer(const definition: TParam): Boolean;
    procedure UpdateTypeArrays(const strLen: string; index: Integer; var collector: TTypeExportInfo);
    function IsLegalSetValue(const Value: string): Boolean;
    function WriteSetValue(const Name, Value: string): Boolean;
    function IsCanWithDelphiTypes(const Command: TCommand): Boolean;
    function GetRealTypeName(const Name: string): string;
    function GenerateCType(const TypeDeclaration: TParam): string;
    function GenerateDelphiType(const TypeDeclaration: TParam): string;
    function GenerateParamsWithDelphiTypes(const Command: TCommand): string;
    function GenerateParamsCStyle(const Command: TCommand; const Info: TCommandInfo): string;
    procedure WriteEnumValue(const Prefix, Name, Value: string);
    procedure WriteSetConst(const Prefix, Name, Value: string; const Groups: TArray<string>);
    procedure WriteType(const DataType: TType);
    function ConvertDefaultCTypeToDelphiEquivalent(FullText: PChar): AnsiString;
    procedure InitializeRequireCommandsAndConsts(const AData: TParsedData; const AOptions: TGeneratorOptions);
    procedure InitializeCommandsParams(const AData: TParsedData; const AOptions: TGeneratorOptions);
    procedure InitializeRemove(const AData: TParsedData; const AOptions: TGeneratorOptions);
    procedure InitializePrepared(const AOptions: TGeneratorOptions);
    procedure WriteEnumOrSet(const Data: TParsedData; EnumGroupIndex: Integer);
    procedure SetTypeUsing(const AData: TParsedData; Index: Integer);
    procedure GenerateAPTypeDeclaration(const AParent: AnsiString; indexes: TArray<TArray<TAPData>>; isGroup: Boolean);
    procedure GenerateDynamicExtensions(const AOptions: TGeneratorOptions);
    function IsUseDynamicExtensions(const AOptions: TGeneratorOptions): Boolean;
  public
    procedure SaveToStream(const AData: TArray<TParsedData>; const AOptions: TGeneratorOptions; AStream: TStream);
    destructor Destroy; override;
  end;

  TStandardCType = (sctDefault, sctChar, sctInt, sctVoid, sctFloat, sctDouble, sctStruct, sctUnion, sctBool);

  //описание простого типа
  TTypeDefinition = record
    Sign: Integer;
    Long: Integer;
    SingleTypeWord: TStandardCType;
    IsTypeDef: Boolean;
    IsConst: Boolean;
    TypeName: string;
    function IsBuildInType: Boolean; inline;
    function DefinedAsBuildInType: Boolean; inline;
    function ToPascalName: string;
    function SetLongValue(AValue: Integer): Boolean;
    function SetStandatdType(AType: TStandardCType): Boolean;
    function IsEmpty: Boolean; inline;
    procedure Clear; inline;
  end;

  TParsedIntConst = record
    RealValue: Integer;
    class operator Implicit(Value: Integer): TParsedIntConst; inline;
  end;

  //описание спецификации массивов и указателей
  TAPInfo = record
    PointerCount: Integer;
    IsConst: Boolean;
    ArraySpecific: array of TParsedIntConst;
    function IsEmpty: Boolean; inline;
    procedure Clear; inline;
    procedure UpgradeLastArraySize(NumeralSystem, Value: Integer);
    constructor Create(APointerCount: Integer; AIsConst: Boolean; const ASpec: array of TParsedIntConst);
    class operator Equal(const A, B: TAPInfo): Boolean;
    class operator NotEqual(const A, B: TAPInfo): Boolean;
    class operator Implicit(const V: TAPInfo): TAPData;
  end;

  TStandardType = (stInt, stUInt, stVoid, stFloat, stStruct, stOtherType);

  TTypedObject = record
    Name, ParentType: string;
    IsConst: Boolean;
    // if filled and StandardType equal stStruct than this is list of fields
    // in another way this is arguments of function
    FieldsOrArgument: array of TTypedObject;
    APSpecific: TArray<TAPInfo>; //спецификация указателей и массивов у объекта
    constructor Create(const Parsed: TTypeDefinition; Converter: TCTypeConverter);
    constructor CreateClear(AStandardType: TStandardType; const AName: string);
    constructor CreateFull(const AName: string; const AParentType: string; AStandardType: TStandardType;
        const APSpec: array of TAPInfo; const AFOA: array of TTypedObject); overload;
    constructor CreateFull(const AName: string; AStandardType: TStandardType;
        ABitLength: Integer); overload;
    class operator Equal(const A, B: TTypedObject): Boolean;
    class operator NotEqual(const A, B: TTypedObject): Boolean; inline;
    function ToPascalName(ADefinition: string; AddNewTypes: Boolean): string;
    procedure FillBuildInType(const Parsed: TTypeDefinition);
    procedure FillAP(const AP: array of TAPInfo);
    procedure Clear;
    function GetAPInfo: TArray<TAPData>;
    function IsEmpty: Boolean; inline;
  case StandardType: TStandardType of
    stOtherType, stStruct: ();
    stInt, stUInt, stVoid, stFloat: (BitLength: Integer);
  end;

  //описание объекта
  TParsedTypedObject = record
    Name: string;

    FunctionData: array of TParsedTypedObject;
    APSpecific: TArray<TAPInfo>; //спецификация указателей и массивов у объекта
    procedure CheckAPSpecificLength(ALength: Integer);
    procedure Clear;
  end;

  //описание объектов одного типа
  TParsedTypedObjectGroup = record
    TypeDefinition: TTypeDefinition;
    DefinedType: string;
    IsDefinedStructOrEnum: Boolean;
    CurrentAP: TAPInfo;
    APStack: TListRecord<TAPInfo>;
    _Object: TTypedObject;
    procedure Clear;
    procedure FixCurrentAP;
  end;

  PTypedObject = ^TTypedObject;

  TCTypeConverter = class (TLR1)
  protected
    FTypeFinished: TList<TAPInfo>;
    FCurrentObject: TParsedTypedObjectGroup;
    FParsedTypes: TDictionary<string, TParsedTypedObjectGroup>;
    FCurrentReaderStack: TListRecord<TParsedTypedObjectGroup>;
    FConvertedTypesList: TListRecord<TTypedObject>;
    FTypesDictionary: TDictionary<string, Integer>;
    FObjectsDictionary: TDictionary<string, Integer>;
    FObjects: TListRecord<TTypedObject>;
    FForwardDefinedStructures: TStringList;
    FAnonymousTypesCount: Integer;
    FNumeralSystem: Integer;
    class procedure BeginName(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure GoDeepType(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure GoUpType(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure UniversalEndName(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure TypedefEnd(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure SignedEnd(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure UnsignedEnd(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure StructEnd(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure ShortEnd(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure LongEnd(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure IntEnd(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure FloatEnd(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure DoubleEnd(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure CharEnd(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure VoidEnd(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure GrowPointerLevel(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure SelectCustomTypeOrName(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure ReadCustomTypeName(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure GoFunctionReader(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure UpdateNumberArraySize(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure UpdateHexNumberArraySize(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure SelectArrayDecNumeralSystem(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure SelectArrayHexNumeralSystem(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure SelectArrayOctalNumeralSystem(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure SelectArrayBinNumeralSystem(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static; //c++ 14
    class procedure NewArraySize(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure EndArraySize(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure EndOfObjectsDeclaration(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure EndOfObjectDeclaration(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure ConstTypeEnd(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure BeginStructUnion(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
    class procedure EndStructUnion(Self: TLR1; ACurrentKey: UCS4Char; ACurrentState: Integer); static;
  private const
    _magazine_begin = UCS4Char(-1);
    _magazine_begin_name = UCS4Char(-2);
    _state_name_next = 1;
    _state_type_name = 2;
    _state_size_begin = 1;

    // unsigned int short typedef const    * const * const test [5]
    // --------------------------------    --------------- ---- --------
    //     first type part                  pointer part name  array part

    // int

    // int *x[5]  is an array of five pointers to int.
    // x: array [5] of ^Integer;
    // int (*x)[5]   is a pointer to an array of five ints.
    // x: ^(array [5] of Integer);
    // int *(*x)[5] is a pointer to an array of five pointers to int
    //     ^--------------
    // x: ^(array [5] of ^Integer)
    // int *(*x[5])[2] is an array of five pointers to an array of two pointers to int
    // x: array [5] of ^(array [2] of ^Integer);
    // int (*x[5])[2] is an array of five pointers to and array of two to ints
    // x: array [5] of ^(array [2] of Integer);
    //
    // int const* is pointer to const int
    // int *const is const pointer to int
    // int const* const is const pointer to const int

    _state_readTypedef = 0; //try to read typedef (t already readed)
    _state_readFirstTypePart = 1;
    _state_readUnsigned = 2; //try to read unsigned (u already readed)
    _state_readSignedOrStructOrShort = 3; //try to read signed, struct or short (s already readed)
    _state_readCustomType = 4; //try to read custom type name (maybe some first chars already readed)
    _state_readSkipSpaces = 5;
    _state_readArrayTypePart = 6;
    _state_read_type_definition2 = 7; //try to read typedef (typed already readed)
    _state_readStruct = 8; //try to read struct (st already readed)
    _state_readSigned = 9; //try to read signed (si already readed)
    _state_readLong = 10; //try to read long (l already readed)
    _state_readInt = 11; //try to read int (i already readed)
    _state_readFloat = 12; //try to read float (f already readed)
    _state_readDouble = 13; //try to read double (d already readed)
    _state_readCharConst = 14; //try to read char (c already readed)
    _state_readUnsigned2 = 15; //try to read unsigned (uns already readed)
    _state_readStruct2 = 16; //try to read struct (struct already readed)
    _state_readShort = 17; //try to read short (sh already readed)
    _state_readSecondTypePart = 18; //try to read new variables or types or arguments names
    _state_readNameTypePart = 19; //try to read new variables or types or arguments names (first char already readed)
    _state_readThirdTypePart = 20; //try read arrays or function defenition
    _state_readArrayDecNumberSize = 21;
    _state_readArrayHexNumberSize = 22;
    _state_readArrayBinNumberSize = 23;
    _state_readArrayOctalNumberSize = 24;
    _state_readArrayEndSize = 25;
    _state_readVoid = 26;
    _state_readChar = 27;
    _state_readConst = 28;
    _state_readConstPointer = 29;

    _skip_spaces: array [0..4] of TKeyTransition = (
      (BeginKey: ord(' '); EndKey: ord(' '); NextState: 0; Action: TLR1.SkipAndContinue),
      (BeginKey: $D; EndKey: $D; NextState: 0; Action: TLR1.SkipAndContinue),
      (BeginKey: $A; EndKey: $A; NextState: 0; Action: TLR1.SkipAndContinue),
      (BeginKey: $9; EndKey: $9; NextState: 0; Action: TLR1.SkipAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: 0; Action: TLR1.RepeatAndBack)
      );

    _magazine_skip_spaces: array [0..0] of TMagazineTransition = (
      (BeginMagazine: 0; EndMagazine: _end; KeyTransitions: @TCTypeConverter._skip_spaces; KeyTransitionsLength: Length(TCTypeConverter._skip_spaces))
      );

    _type_name: array [0..5] of TKeyTransition = (
      (BeginKey: ord('*'); EndKey: ord('*'); NextState: _state_readTypedef; Action: TCTypeConverter.GrowPointerLevel),//создать указатель на тип
      (BeginKey: ord('('); EndKey: ord('('); NextState: _state_readTypedef; Action: TCTypeConverter.GoDeepType),
      (BeginKey: ord('a'); EndKey: ord('z'); NextState: _state_readTypedef; Action: TCTypeConverter.BeginName),
      (BeginKey: ord('A'); EndKey: ord('Z'); NextState: _state_readTypedef; Action: TCTypeConverter.BeginName),
      (BeginKey: ord('_'); EndKey: ord('_'); NextState: _state_readTypedef; Action: TCTypeConverter.BeginName),
      (BeginKey: ord(' '); EndKey: ord(' '); NextState: _state_readTypedef; Action: TLR1.SkipAndGo)
      );
    _type_array_size: array [0..1] of TKeyTransition = (
      (BeginKey: ord('0'); EndKey: ord('0'); NextState: _state_readTypedef; Action: nil),
      (BeginKey: ord('1'); EndKey: ord('9'); NextState: _state_readTypedef; Action: nil)
      );
    _type_array_size_begin: array [0..2] of TKeyTransition = (
      (BeginKey: ord('0'); EndKey: ord('0'); NextState: _state_readTypedef; Action: nil),
      (BeginKey: ord('1'); EndKey: ord('9'); NextState: _state_readTypedef; Action: nil),
      (BeginKey: ord(' '); EndKey: ord(' '); NextState: _state_readTypedef; Action: TLR1.SkipAndGo)
      );
    _type_array_begin: array [0..1] of TKeyTransition = (
      (BeginKey: ord('['); EndKey: ord('['); NextState: _state_readTypedef; Action: nil),
      (BeginKey: ord(' '); EndKey: ord(' '); NextState: 0; Action: nil)
      );
    _state_0_0: array [0..0] of TKeyTransition = (
      (BeginKey: 0; EndKey: $1ffff; NextState: 0; Action: nil)
      );

    {$region 'read typedef'}
    _typedef_1: array [0..1] of TKeyTransition = (
      (BeginKey: ord('y'); EndKey: ord('y'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _typedef_2: array [0..1] of TKeyTransition = (
      (BeginKey: ord('p'); EndKey: ord('p'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _typedef_3_5: array [0..1] of TKeyTransition = (
      (BeginKey: ord('e'); EndKey: ord('e'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _typedef_4: array [0..1] of TKeyTransition = (
      (BeginKey: ord('d'); EndKey: ord('d'); NextState: _state_read_type_definition2; Action: TLR1.PushAndGo),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _typedef_6: array [0..1] of TKeyTransition = (
      (BeginKey: ord('f'); EndKey: ord('f'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _typedef_end: array [0..4] of TKeyTransition = (
      (BeginKey: ord('a'); EndKey: ord('z'); NextState: 0; Action: TLR1.BreakAction),
      (BeginKey: ord('A'); EndKey: ord('Z'); NextState: 0; Action: TLR1.BreakAction),
      (BeginKey: ord('0'); EndKey: ord('9'); NextState: 0; Action: TLR1.BreakAction),
      (BeginKey: ord('_'); EndKey: ord('_'); NextState: 0; Action: TLR1.BreakAction),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readFirstTypePart; Action: TCTypeConverter.TypedefEnd)
      );
    _magazine_typedef_0: array [0..3] of TMagazineTransition = (
      (BeginMagazine: ord('t'); EndMagazine: ord('t'); KeyTransitions: @TCTypeConverter._typedef_1; KeyTransitionsLength: Length(TCTypeConverter._typedef_1)),
      (BeginMagazine: ord('y'); EndMagazine: ord('y'); KeyTransitions: @TCTypeConverter._typedef_2; KeyTransitionsLength: Length(TCTypeConverter._typedef_2)),
      (BeginMagazine: ord('p'); EndMagazine: ord('p'); KeyTransitions: @TCTypeConverter._typedef_3_5; KeyTransitionsLength: Length(TCTypeConverter._typedef_3_5)),
      (BeginMagazine: ord('e'); EndMagazine: ord('e'); KeyTransitions: @TCTypeConverter._typedef_4; KeyTransitionsLength: Length(TCTypeConverter._typedef_4))
      );
    _magazine_typedef_1: array [0..2] of TMagazineTransition = (
      (BeginMagazine: ord('d'); EndMagazine: ord('d'); KeyTransitions: @TCTypeConverter._typedef_3_5; KeyTransitionsLength: Length(TCTypeConverter._typedef_3_5)),
      (BeginMagazine: ord('e'); EndMagazine: ord('e'); KeyTransitions: @TCTypeConverter._typedef_6; KeyTransitionsLength: Length(TCTypeConverter._typedef_6)),
      (BeginMagazine: ord('f'); EndMagazine: ord('f'); KeyTransitions: @TCTypeConverter._typedef_end; KeyTransitionsLength: Length(TCTypeConverter._typedef_end))
      );
    {$endregion}

    {$region 'read void'}
    _type_void_1: array [0..1] of TKeyTransition = (
      (BeginKey: ord('o'); EndKey: ord('o'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_void_2: array [0..1] of TKeyTransition = (
      (BeginKey: ord('i'); EndKey: ord('i'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_void_3: array [0..1] of TKeyTransition = (
      (BeginKey: ord('d'); EndKey: ord('i'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_void_end: array [0..4] of TKeyTransition = (
      (BeginKey: ord('a'); EndKey: ord('z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo), //all other names
      (BeginKey: ord('A'); EndKey: ord('Z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('_'); EndKey: ord('_'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('0'); EndKey: ord('9'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readFirstTypePart; Action: TCTypeConverter.VoidEnd)
      );
    _magazine_void: array [0..3] of TMagazineTransition = (
      (BeginMagazine: ord('v'); EndMagazine: ord('v'); KeyTransitions: @TCTypeConverter._type_void_1; KeyTransitionsLength: Length(TCTypeConverter._type_void_1)),
      (BeginMagazine: ord('o'); EndMagazine: ord('o'); KeyTransitions: @TCTypeConverter._type_void_2; KeyTransitionsLength: Length(TCTypeConverter._type_void_2)),
      (BeginMagazine: ord('i'); EndMagazine: ord('i'); KeyTransitions: @TCTypeConverter._type_void_3; KeyTransitionsLength: Length(TCTypeConverter._type_void_3)),
      (BeginMagazine: ord('d'); EndMagazine: ord('d'); KeyTransitions: @TCTypeConverter._type_void_end; KeyTransitionsLength: Length(TCTypeConverter._type_void_end))
      );
    {$endregion}

    _default_type_begin: array [0..18] of TKeyTransition = (
      (BeginKey: ord('u'); EndKey: ord('u'); NextState: _state_readUnsigned; Action: TLR1.PushAndGo), //maybe unsigned
      (BeginKey: ord('s'); EndKey: ord('s'); NextState: _state_readSignedOrStructOrShort; Action: TLR1.PushAndGo), //maybe signed or struct or short
      (BeginKey: ord('l'); EndKey: ord('l'); NextState: _state_readLong; Action: TLR1.PushAndGo), //maybe long
      (BeginKey: ord('i'); EndKey: ord('i'); NextState: _state_readInt; Action: TLR1.PushAndGo), //maybe int
      (BeginKey: ord('f'); EndKey: ord('f'); NextState: _state_readFloat; Action: TLR1.PushAndGo), //maybe float
      (BeginKey: ord('d'); EndKey: ord('d'); NextState: _state_readDouble; Action: TLR1.PushAndGo), //maybe double
      (BeginKey: ord('c'); EndKey: ord('c'); NextState: _state_readCharConst; Action: TLR1.PushAndGo), //maybe char/const
      (BeginKey: ord('t'); EndKey: ord('t'); NextState: _state_readTypedef; Action: TLR1.PushAndGo), //maybe typedef
      (BeginKey: ord('v'); EndKey: ord('v'); NextState: _state_readVoid; Action: TLR1.PushAndGo), //maybe void
      (BeginKey: ord('*'); EndKey: ord('*'); NextState: _state_readSecondTypePart; Action: TCTypeConverter.GrowPointerLevel), //pointer start
      (BeginKey: ord('('); EndKey: ord('('); NextState: _state_readSecondTypePart; Action: TCTypeConverter.GoDeepType),
      (BeginKey: ord('}'); EndKey: ord('}'); NextState: _state_readSecondTypePart; Action: TCTypeConverter.EndStructUnion),
      (BeginKey: ord('a'); EndKey: ord('z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo), //all other names
      (BeginKey: ord('A'); EndKey: ord('Z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('_'); EndKey: ord('_'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord(' '); EndKey: ord(' '); NextState: 0; Action: TLR1.SkipAndContinue),
      (BeginKey: $D; EndKey: $D; NextState: 0; Action: TLR1.SkipAndContinue),
      (BeginKey: $A; EndKey: $A; NextState: 0; Action: TLR1.SkipAndContinue),
      (BeginKey: $9; EndKey: $9; NextState: 0; Action: TLR1.SkipAndContinue)
      );
    _magazine_firstTypePart: array [0..0] of TMagazineTransition = (
      (BeginMagazine: 0; EndMagazine: _end; KeyTransitions: @TCTypeConverter._default_type_begin; KeyTransitionsLength: Length(TCTypeConverter._default_type_begin))
      );

    {$region 'read signed'}
    _type_signed_2: array [0..1] of TKeyTransition = (
      (BeginKey: ord('g'); EndKey: ord('g'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_signed_3: array [0..1] of TKeyTransition = (
      (BeginKey: ord('n'); EndKey: ord('n'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_signed_4: array [0..1] of TKeyTransition = (
      (BeginKey: ord('e'); EndKey: ord('e'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_signed_5: array [0..1] of TKeyTransition = (
      (BeginKey: ord('d'); EndKey: ord('d'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_signed_end: array [0..4] of TKeyTransition = (
      (BeginKey: ord('a'); EndKey: ord('z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo), //all other names
      (BeginKey: ord('A'); EndKey: ord('Z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('_'); EndKey: ord('_'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('0'); EndKey: ord('9'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readFirstTypePart; Action: TCTypeConverter.SignedEnd)
      );
    _magazine_Signed: array [0..4] of TMagazineTransition = (
      (BeginMagazine: ord('i'); EndMagazine: ord('i'); KeyTransitions: @TCTypeConverter._type_signed_2; KeyTransitionsLength: Length(TCTypeConverter._type_signed_2)),
      (BeginMagazine: ord('g'); EndMagazine: ord('g'); KeyTransitions: @TCTypeConverter._type_signed_3; KeyTransitionsLength: Length(TCTypeConverter._type_signed_3)),
      (BeginMagazine: ord('n'); EndMagazine: ord('n'); KeyTransitions: @TCTypeConverter._type_signed_4; KeyTransitionsLength: Length(TCTypeConverter._type_signed_4)),
      (BeginMagazine: ord('e'); EndMagazine: ord('e'); KeyTransitions: @TCTypeConverter._type_signed_5; KeyTransitionsLength: Length(TCTypeConverter._type_signed_5)),
      (BeginMagazine: ord('d'); EndMagazine: ord('d'); KeyTransitions: @TCTypeConverter._type_signed_end; KeyTransitionsLength: Length(TCTypeConverter._type_signed_end))
      );
    {$endregion}

    {$region 'read unsigned'}
    _type_unsigned_1: array [0..1] of TKeyTransition = (
      (BeginKey: ord('n'); EndKey: ord('n'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_unsigned_2: array [0..1] of TKeyTransition = (
      (BeginKey: ord('s'); EndKey: ord('s'); NextState: _state_readUnsigned2; Action: TLR1.PushAndGo),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_unsigned_3: array [0..1] of TKeyTransition = (
      (BeginKey: ord('i'); EndKey: ord('i'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_unsigned_end: array [0..4] of TKeyTransition = (
      (BeginKey: ord('a'); EndKey: ord('z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo), //all other names
      (BeginKey: ord('A'); EndKey: ord('Z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('_'); EndKey: ord('_'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('0'); EndKey: ord('9'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readFirstTypePart; Action: TCTypeConverter.UnsignedEnd)
      );
    _magazine_Unsigned: array [0..1] of TMagazineTransition = (
      (BeginMagazine: ord('u'); EndMagazine: ord('u'); KeyTransitions: @TCTypeConverter._type_unsigned_1; KeyTransitionsLength: Length(TCTypeConverter._type_unsigned_1)),
      (BeginMagazine: ord('n'); EndMagazine: ord('n'); KeyTransitions: @TCTypeConverter._type_unsigned_2; KeyTransitionsLength: Length(TCTypeConverter._type_unsigned_2))
      );
    _magazine_Unsigned2: array [0..5] of TMagazineTransition = (
      (BeginMagazine: ord('s'); EndMagazine: ord('s'); KeyTransitions: @TCTypeConverter._type_unsigned_3; KeyTransitionsLength: Length(TCTypeConverter._type_unsigned_3)),
      (BeginMagazine: ord('i'); EndMagazine: ord('i'); KeyTransitions: @TCTypeConverter._type_signed_2; KeyTransitionsLength: Length(TCTypeConverter._type_signed_2)),
      (BeginMagazine: ord('g'); EndMagazine: ord('g'); KeyTransitions: @TCTypeConverter._type_signed_3; KeyTransitionsLength: Length(TCTypeConverter._type_signed_3)),
      (BeginMagazine: ord('n'); EndMagazine: ord('n'); KeyTransitions: @TCTypeConverter._type_signed_4; KeyTransitionsLength: Length(TCTypeConverter._type_signed_4)),
      (BeginMagazine: ord('e'); EndMagazine: ord('e'); KeyTransitions: @TCTypeConverter._type_signed_5; KeyTransitionsLength: Length(TCTypeConverter._type_signed_5)),
      (BeginMagazine: ord('d'); EndMagazine: ord('d'); KeyTransitions: @TCTypeConverter._type_unsigned_end; KeyTransitionsLength: Length(TCTypeConverter._type_unsigned_end))
      );
    {$endregion}

    {$region 'read struct'}
    _type_struct_2: array [0..1] of TKeyTransition = (
      (BeginKey: ord('r'); EndKey: ord('r'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_struct_3: array [0..1] of TKeyTransition = (
      (BeginKey: ord('u'); EndKey: ord('u'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_struct_4: array [0..1] of TKeyTransition = (
      (BeginKey: ord('c'); EndKey: ord('c'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_struct_5: array [0..1] of TKeyTransition = (
      (BeginKey: ord('t'); EndKey: ord('t'); NextState: _state_readStruct2; Action: TLR1.PushAndGo),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_struct_end: array [0..4] of TKeyTransition = (
      (BeginKey: ord('a'); EndKey: ord('z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo), //all other names
      (BeginKey: ord('A'); EndKey: ord('Z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('_'); EndKey: ord('_'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('0'); EndKey: ord('9'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readSkipSpaces; Action: TCTypeConverter.StructEnd)
      );
    _magazine_Struct: array [0..3] of TMagazineTransition = (
      (BeginMagazine: ord('t'); EndMagazine: ord('t'); KeyTransitions: @TCTypeConverter._type_struct_2; KeyTransitionsLength: Length(TCTypeConverter._type_struct_2)),
      (BeginMagazine: ord('r'); EndMagazine: ord('r'); KeyTransitions: @TCTypeConverter._type_struct_3; KeyTransitionsLength: Length(TCTypeConverter._type_struct_3)),
      (BeginMagazine: ord('u'); EndMagazine: ord('u'); KeyTransitions: @TCTypeConverter._type_struct_4; KeyTransitionsLength: Length(TCTypeConverter._type_struct_4)),
      (BeginMagazine: ord('c'); EndMagazine: ord('c'); KeyTransitions: @TCTypeConverter._type_struct_5; KeyTransitionsLength: Length(TCTypeConverter._type_struct_5))
     );
    _magazine_Struct2: array [0..0] of TMagazineTransition = (
      (BeginMagazine: ord('t'); EndMagazine: ord('t'); KeyTransitions: @TCTypeConverter._type_struct_end; KeyTransitionsLength: Length(TCTypeConverter._type_struct_end))
      );
    {$endregion}

    {$region 'read short'}
    _type_short_2: array [0..1] of TKeyTransition = (
      (BeginKey: ord('o'); EndKey: ord('o'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_short_3: array [0..1] of TKeyTransition = (
      (BeginKey: ord('r'); EndKey: ord('r'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_short_4: array [0..1] of TKeyTransition = (
      (BeginKey: ord('t'); EndKey: ord('t'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_short_end: array [0..4] of TKeyTransition = (
      (BeginKey: ord('a'); EndKey: ord('z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo), //all other names
      (BeginKey: ord('A'); EndKey: ord('Z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('_'); EndKey: ord('_'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('0'); EndKey: ord('9'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readFirstTypePart; Action: TCTypeConverter.ShortEnd)
      );
    _magazine_Short: array [0..3] of TMagazineTransition = (
      (BeginMagazine: ord('h'); EndMagazine: ord('h'); KeyTransitions: @TCTypeConverter._type_short_2; KeyTransitionsLength: Length(TCTypeConverter._type_short_2)),
      (BeginMagazine: ord('o'); EndMagazine: ord('o'); KeyTransitions: @TCTypeConverter._type_short_3; KeyTransitionsLength: Length(TCTypeConverter._type_short_3)),
      (BeginMagazine: ord('r'); EndMagazine: ord('r'); KeyTransitions: @TCTypeConverter._type_short_4; KeyTransitionsLength: Length(TCTypeConverter._type_short_4)),
      (BeginMagazine: ord('t'); EndMagazine: ord('t'); KeyTransitions: @TCTypeConverter._type_short_end; KeyTransitionsLength: Length(TCTypeConverter._type_short_end))
     );
     {$endregion}

    _type_signed_struct_short_1: array [0..3] of TKeyTransition = (
      (BeginKey: ord('i'); EndKey: ord('i'); NextState: _state_readSigned; Action: TLR1.PushAndGo),
      (BeginKey: ord('t'); EndKey: ord('t'); NextState: _state_readStruct; Action: TLR1.PushAndGo),
      (BeginKey: ord('h'); EndKey: ord('h'); NextState: _state_readShort; Action: TLR1.PushAndGo),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.PushAndGo) //all other names
      );
    _magazine_SignedOrStructOrShort: array [0..0] of TMagazineTransition = (
      (BeginMagazine: ord('s'); EndMagazine: ord('s'); KeyTransitions: @TCTypeConverter._type_signed_struct_short_1; KeyTransitionsLength: Length(TCTypeConverter._type_signed_struct_short_1))
      );

    {$region 'read long'}
    _type_long_1: array [0..1] of TKeyTransition = (
      (BeginKey: ord('o'); EndKey: ord('o'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_long_2: array [0..1] of TKeyTransition = (
      (BeginKey: ord('n'); EndKey: ord('n'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_long_3: array [0..1] of TKeyTransition = (
      (BeginKey: ord('g'); EndKey: ord('g'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_long_end: array [0..4] of TKeyTransition = (
      (BeginKey: ord('a'); EndKey: ord('z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo), //all other names
      (BeginKey: ord('A'); EndKey: ord('Z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('_'); EndKey: ord('_'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('0'); EndKey: ord('9'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readFirstTypePart; Action: TCTypeConverter.LongEnd)
      );
    _magazine_Long: array [0..3] of TMagazineTransition = (
      (BeginMagazine: ord('l'); EndMagazine: ord('l'); KeyTransitions: @TCTypeConverter._type_long_1; KeyTransitionsLength: Length(TCTypeConverter._type_long_1)),
      (BeginMagazine: ord('o'); EndMagazine: ord('o'); KeyTransitions: @TCTypeConverter._type_long_2; KeyTransitionsLength: Length(TCTypeConverter._type_long_2)),
      (BeginMagazine: ord('n'); EndMagazine: ord('n'); KeyTransitions: @TCTypeConverter._type_long_3; KeyTransitionsLength: Length(TCTypeConverter._type_long_3)),
      (BeginMagazine: ord('g'); EndMagazine: ord('g'); KeyTransitions: @TCTypeConverter._type_long_end; KeyTransitionsLength: Length(TCTypeConverter._type_long_end))
      );
    {$endregion}

    {$region 'read int'}
    _type_int_1: array [0..1] of TKeyTransition = (
      (BeginKey: ord('n'); EndKey: ord('n'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_int_2: array [0..1] of TKeyTransition = (
      (BeginKey: ord('t'); EndKey: ord('t'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_int_end: array [0..4] of TKeyTransition = (
      (BeginKey: ord('a'); EndKey: ord('z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo), //all other names
      (BeginKey: ord('A'); EndKey: ord('Z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('_'); EndKey: ord('_'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('0'); EndKey: ord('9'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readFirstTypePart; Action: TCTypeConverter.IntEnd)
      );
    _magazine_Int: array [0..2] of TMagazineTransition = (
      (BeginMagazine: ord('i'); EndMagazine: ord('i'); KeyTransitions: @TCTypeConverter._type_int_1; KeyTransitionsLength: Length(TCTypeConverter._type_int_1)),
      (BeginMagazine: ord('n'); EndMagazine: ord('n'); KeyTransitions: @TCTypeConverter._type_int_2; KeyTransitionsLength: Length(TCTypeConverter._type_int_2)),
      (BeginMagazine: ord('t'); EndMagazine: ord('t'); KeyTransitions: @TCTypeConverter._type_int_end; KeyTransitionsLength: Length(TCTypeConverter._type_int_end))
      );
    {$endregion}

    {$region 'read float'}
    _type_float_1: array [0..1] of TKeyTransition = (
      (BeginKey: ord('l'); EndKey: ord('l'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_float_2: array [0..1] of TKeyTransition = (
      (BeginKey: ord('o'); EndKey: ord('o'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_float_3: array [0..1] of TKeyTransition = (
      (BeginKey: ord('a'); EndKey: ord('a'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_float_4: array [0..1] of TKeyTransition = (
      (BeginKey: ord('t'); EndKey: ord('t'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_float_end: array [0..4] of TKeyTransition = (
      (BeginKey: ord('a'); EndKey: ord('z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo), //all other names
      (BeginKey: ord('A'); EndKey: ord('Z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('_'); EndKey: ord('_'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('0'); EndKey: ord('9'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readFirstTypePart; Action: TCTypeConverter.FloatEnd)
      );
    _magazine_Float: array [0..4] of TMagazineTransition = (
      (BeginMagazine: ord('f'); EndMagazine: ord('f'); KeyTransitions: @TCTypeConverter._type_float_1; KeyTransitionsLength: Length(TCTypeConverter._type_float_1)),
      (BeginMagazine: ord('l'); EndMagazine: ord('l'); KeyTransitions: @TCTypeConverter._type_float_2; KeyTransitionsLength: Length(TCTypeConverter._type_float_2)),
      (BeginMagazine: ord('o'); EndMagazine: ord('o'); KeyTransitions: @TCTypeConverter._type_float_3; KeyTransitionsLength: Length(TCTypeConverter._type_float_3)),
      (BeginMagazine: ord('a'); EndMagazine: ord('a'); KeyTransitions: @TCTypeConverter._type_float_4; KeyTransitionsLength: Length(TCTypeConverter._type_float_4)),
      (BeginMagazine: ord('t'); EndMagazine: ord('t'); KeyTransitions: @TCTypeConverter._type_float_end; KeyTransitionsLength: Length(TCTypeConverter._type_float_end))
      );
    {$endregion}

    {$region 'read double'}
    _type_double_1: array [0..1] of TKeyTransition = (
      (BeginKey: ord('o'); EndKey: ord('o'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_double_2: array [0..1] of TKeyTransition = (
      (BeginKey: ord('u'); EndKey: ord('u'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_double_3: array [0..1] of TKeyTransition = (
      (BeginKey: ord('b'); EndKey: ord('b'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_double_4: array [0..1] of TKeyTransition = (
      (BeginKey: ord('l'); EndKey: ord('l'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_double_5: array [0..1] of TKeyTransition = (
      (BeginKey: ord('e'); EndKey: ord('e'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_double_end: array [0..4] of TKeyTransition = (
      (BeginKey: ord('a'); EndKey: ord('z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo), //all other names
      (BeginKey: ord('A'); EndKey: ord('Z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('_'); EndKey: ord('_'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('0'); EndKey: ord('9'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readFirstTypePart; Action: TCTypeConverter.DoubleEnd)
      );
    _magazine_Double: array [0..5] of TMagazineTransition = (
      (BeginMagazine: ord('d'); EndMagazine: ord('d'); KeyTransitions: @TCTypeConverter._type_double_1; KeyTransitionsLength: Length(TCTypeConverter._type_double_1)),
      (BeginMagazine: ord('o'); EndMagazine: ord('o'); KeyTransitions: @TCTypeConverter._type_double_2; KeyTransitionsLength: Length(TCTypeConverter._type_double_2)),
      (BeginMagazine: ord('u'); EndMagazine: ord('u'); KeyTransitions: @TCTypeConverter._type_double_3; KeyTransitionsLength: Length(TCTypeConverter._type_double_3)),
      (BeginMagazine: ord('b'); EndMagazine: ord('b'); KeyTransitions: @TCTypeConverter._type_double_4; KeyTransitionsLength: Length(TCTypeConverter._type_double_4)),
      (BeginMagazine: ord('l'); EndMagazine: ord('l'); KeyTransitions: @TCTypeConverter._type_double_5; KeyTransitionsLength: Length(TCTypeConverter._type_double_5)),
      (BeginMagazine: ord('e'); EndMagazine: ord('e'); KeyTransitions: @TCTypeConverter._type_double_end; KeyTransitionsLength: Length(TCTypeConverter._type_double_end))
       );
    {$endregion}

    {$region 'read char'}
    _type_char_2: array [0..1] of TKeyTransition = (
      (BeginKey: ord('a'); EndKey: ord('a'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_char_3: array [0..1] of TKeyTransition = (
      (BeginKey: ord('r'); EndKey: ord('r'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_char_end: array [0..4] of TKeyTransition = (
      (BeginKey: ord('a'); EndKey: ord('z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo), //all other names
      (BeginKey: ord('A'); EndKey: ord('Z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('_'); EndKey: ord('_'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('0'); EndKey: ord('9'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readFirstTypePart; Action: TCTypeConverter.CharEnd)
      );
    _magazine_Char: array [0..2] of TMagazineTransition = (
      (BeginMagazine: ord('h'); EndMagazine: ord('h'); KeyTransitions: @TCTypeConverter._type_char_2; KeyTransitionsLength: Length(TCTypeConverter._type_char_2)),
      (BeginMagazine: ord('a'); EndMagazine: ord('a'); KeyTransitions: @TCTypeConverter._type_char_3; KeyTransitionsLength: Length(TCTypeConverter._type_char_3)),
      (BeginMagazine: ord('r'); EndMagazine: ord('r'); KeyTransitions: @TCTypeConverter._type_char_end; KeyTransitionsLength: Length(TCTypeConverter._type_char_end))
      );
    {$endregion}

    {$region 'read const'}
    _type_const_2: array [0..1] of TKeyTransition = (
      (BeginKey: ord('n'); EndKey: ord('n'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_const_3: array [0..1] of TKeyTransition = (
      (BeginKey: ord('s'); EndKey: ord('s'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_const_4: array [0..1] of TKeyTransition = (
      (BeginKey: ord('t'); EndKey: ord('t'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_const_end: array [0..4] of TKeyTransition = (
      (BeginKey: ord('a'); EndKey: ord('z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo), //all other names
      (BeginKey: ord('A'); EndKey: ord('Z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('_'); EndKey: ord('_'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('0'); EndKey: ord('9'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readFirstTypePart; Action: TCTypeConverter.ConstTypeEnd)
      );
    _magazine_Const: array [0..3] of TMagazineTransition = (
      (BeginMagazine: ord('o'); EndMagazine: ord('o'); KeyTransitions: @TCTypeConverter._type_const_2; KeyTransitionsLength: Length(TCTypeConverter._type_const_2)),
      (BeginMagazine: ord('n'); EndMagazine: ord('n'); KeyTransitions: @TCTypeConverter._type_const_3; KeyTransitionsLength: Length(TCTypeConverter._type_const_3)),
      (BeginMagazine: ord('s'); EndMagazine: ord('s'); KeyTransitions: @TCTypeConverter._type_const_4; KeyTransitionsLength: Length(TCTypeConverter._type_const_4)),
      (BeginMagazine: ord('t'); EndMagazine: ord('t'); KeyTransitions: @TCTypeConverter._type_const_end; KeyTransitionsLength: Length(TCTypeConverter._type_const_end))
      );

    _type_const_pointer_1: array [0..1] of TKeyTransition = (
      (BeginKey: ord('o'); EndKey: ord('o'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readNameTypePart; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_const_pointer_2: array [0..1] of TKeyTransition = (
      (BeginKey: ord('n'); EndKey: ord('n'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readNameTypePart; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_const_pointer_3: array [0..1] of TKeyTransition = (
      (BeginKey: ord('s'); EndKey: ord('s'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readNameTypePart; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_const_pointer_4: array [0..1] of TKeyTransition = (
      (BeginKey: ord('t'); EndKey: ord('t'); NextState: 0; Action: TLR1.PushAndContinue),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readNameTypePart; Action: TLR1.RepeatAtNewState) //all other names
      );
    _type_const_pointer_end: array [0..4] of TKeyTransition = (
      (BeginKey: ord('a'); EndKey: ord('z'); NextState: _state_readNameTypePart; Action: TLR1.PushAndGo), //all other names
      (BeginKey: ord('A'); EndKey: ord('Z'); NextState: _state_readNameTypePart; Action: TLR1.PushAndGo),
      (BeginKey: ord('_'); EndKey: ord('_'); NextState: _state_readNameTypePart; Action: TLR1.PushAndGo),
      (BeginKey: ord('0'); EndKey: ord('9'); NextState: _state_readNameTypePart; Action: TLR1.PushAndGo),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readSecondTypePart; Action: TCTypeConverter.ConstTypeEnd)
      );
    _magazine_ConstPointer: array [0..4] of TMagazineTransition = (
      (BeginMagazine: ord('c'); EndMagazine: ord('c'); KeyTransitions: @TCTypeConverter._type_const_pointer_1; KeyTransitionsLength: Length(TCTypeConverter._type_const_pointer_1)),
      (BeginMagazine: ord('o'); EndMagazine: ord('o'); KeyTransitions: @TCTypeConverter._type_const_pointer_2; KeyTransitionsLength: Length(TCTypeConverter._type_const_pointer_2)),
      (BeginMagazine: ord('n'); EndMagazine: ord('n'); KeyTransitions: @TCTypeConverter._type_const_pointer_3; KeyTransitionsLength: Length(TCTypeConverter._type_const_pointer_3)),
      (BeginMagazine: ord('s'); EndMagazine: ord('s'); KeyTransitions: @TCTypeConverter._type_const_pointer_4; KeyTransitionsLength: Length(TCTypeConverter._type_const_pointer_4)),
      (BeginMagazine: ord('t'); EndMagazine: ord('t'); KeyTransitions: @TCTypeConverter._type_const_pointer_end; KeyTransitionsLength: Length(TCTypeConverter._type_const_pointer_end))
      );
    {$endregion}

    _type_char_const_1: array [0..2] of TKeyTransition = (
      (BeginKey: ord('h'); EndKey: ord('h'); NextState: _state_readChar; Action: TLR1.PushAndGo),
      (BeginKey: ord('o'); EndKey: ord('o'); NextState: _state_readConst; Action: TLR1.PushAndGo),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readCustomType; Action: TLR1.PushAndGo) //all other names
      );
    _magazine_Char_Const: array [0..0] of TMagazineTransition = (
      (BeginMagazine: ord('c'); EndMagazine: ord('c'); KeyTransitions: @TCTypeConverter._type_char_const_1; KeyTransitionsLength: Length(TCTypeConverter._type_char_const_1))
      );

    {$region 'read custom type name'}
    _name_type_next: array [0..5] of TKeyTransition = (
      (BeginKey: ord('a'); EndKey: ord('z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('A'); EndKey: ord('Z'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('_'); EndKey: ord('_'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('0'); EndKey: ord('9'); NextState: _state_readCustomType; Action: TLR1.PushAndGo),
      (BeginKey: ord('{'); EndKey: ord('{'); NextState: _state_readFirstTypePart; Action: TCTypeConverter.BeginStructUnion),
      (BeginKey: 0; EndKey: $1ffff; NextState: _state_readSecondTypePart; Action: TCTypeConverter.ReadCustomTypeName)
      );
    _magazine_customTypeName: array [0..0] of TMagazineTransition = (
      (BeginMagazine: 0; EndMagazine: _end; KeyTransitions: @TCTypeConverter._name_type_next; KeyTransitionsLength: Length(TCTypeConverter._name_type_next))
      );
    {$endregion}

    {$region 'read custom name'}
    _name_next: array [0..4] of TKeyTransition = (
      (BeginKey: ord('a'); EndKey: ord('z'); NextState: _state_readNameTypePart; Action: TLR1.PushAndGo),
      (BeginKey: ord('A'); EndKey: ord('Z'); NextState: _state_readNameTypePart; Action: TLR1.PushAndGo),
      (BeginKey: ord('_'); EndKey: ord('_'); NextState: _state_readNameTypePart; Action: TLR1.PushAndGo),
      (BeginKey: ord('0'); EndKey: ord('9'); NextState: _state_readNameTypePart; Action: TLR1.PushAndGo),
      (BeginKey: 0; EndKey: $1ffff; NextState: 0; Action: TCTypeConverter.UniversalEndName)
      );
    _magazine_customName: array [0..0] of TMagazineTransition = (
      (BeginMagazine: 0; EndMagazine: _end; KeyTransitions: @TCTypeConverter._name_next; KeyTransitionsLength: Length(TCTypeConverter._name_next))
      );
    {$endregion}

    {$region 'read second type part const *({ name'}
    _name_SecondTypePart: array [0..11] of TKeyTransition = (
      (BeginKey: ord('c'); EndKey: ord('c'); NextState: _state_readConstPointer; Action: TLR1.PushAndGo), //const
      (BeginKey: ord('a'); EndKey: ord('z'); NextState: _state_readNameTypePart; Action: TLR1.PushAndGo),
      (BeginKey: ord('A'); EndKey: ord('Z'); NextState: _state_readNameTypePart; Action: TLR1.PushAndGo),
      (BeginKey: ord('_'); EndKey: ord('_'); NextState: _state_readNameTypePart; Action: TLR1.PushAndGo),
      (BeginKey: ord('('); EndKey: ord('('); NextState: _state_readSecondTypePart; Action: TCTypeConverter.GoDeepType),
      (BeginKey: ord('*'); EndKey: ord('*'); NextState: _state_readSecondTypePart; Action: TCTypeConverter.GrowPointerLevel),
      (BeginKey: ord('{'); EndKey: ord('{'); NextState: _state_readFirstTypePart; Action: TCTypeConverter.BeginStructUnion),
      (BeginKey: ord(';'); EndKey: ord(';'); NextState: _state_readFirstTypePart; Action: TCTypeConverter.EndOfObjectsDeclaration),
      (BeginKey: $D; EndKey: $D; NextState: _state_readSecondTypePart; Action: TLR1.SkipAndGo),
      (BeginKey: $A; EndKey: $A; NextState: _state_readSecondTypePart; Action: TLR1.SkipAndGo),
      (BeginKey: $9; EndKey: $9; NextState: _state_readSecondTypePart; Action: TLR1.SkipAndGo),
      (BeginKey: ord(' '); EndKey: ord(' '); NextState: _state_readSecondTypePart; Action: TLR1.SkipAndGo)
      );
    _magazine_SecondTypePart: array [0..0] of TMagazineTransition = (
      (BeginMagazine: 0; EndMagazine: _end; KeyTransitions: @TCTypeConverter._name_SecondTypePart; KeyTransitionsLength: Length(TCTypeConverter._name_SecondTypePart))
      );
    {$endregion}

    _name_ThirdTypePart: array [0..9] of TKeyTransition = (
      (BeginKey: ord(','); EndKey: ord(','); NextState: _state_readSecondTypePart; Action: TCTypeConverter.EndOfObjectDeclaration),
      (BeginKey: ord(';'); EndKey: ord(';'); NextState: _state_readFirstTypePart; Action: TCTypeConverter.EndOfObjectsDeclaration),
      (BeginKey: ord(')'); EndKey: ord(')'); NextState: _state_readNameTypePart; Action: TCTypeConverter.GoUpType),
      (BeginKey: ord('['); EndKey: ord('['); NextState: _state_readArrayTypePart; Action: TCTypeConverter.NewArraySize),
      (BeginKey: ord('('); EndKey: ord('('); NextState: _state_readNameTypePart; Action: TCTypeConverter.GoFunctionReader),
      (BeginKey: ord('{'); EndKey: ord('{'); NextState: _state_readFirstTypePart; Action: TCTypeConverter.BeginStructUnion),
      (BeginKey: ord(' '); EndKey: ord(' '); NextState: _state_readThirdTypePart; Action: TLR1.SkipAndGo),
      (BeginKey: $D; EndKey: $D; NextState: _state_readThirdTypePart; Action: TLR1.PushAndGo),
      (BeginKey: $A; EndKey: $A; NextState: _state_readThirdTypePart; Action: TLR1.PushAndGo),
      (BeginKey: $9; EndKey: $9; NextState: _state_readThirdTypePart; Action: TLR1.PushAndGo)
      );
    _magazine_ThirdTypePart: array [0..0] of TMagazineTransition = (
      (BeginMagazine: 0; EndMagazine: _end; KeyTransitions: @TCTypeConverter._name_ThirdTypePart; KeyTransitionsLength: Length(TCTypeConverter._name_ThirdTypePart))
      );

    {$region 'read array size'}
    _array_sizePart: array [0..6] of TKeyTransition = (
      (BeginKey: ord('0'); EndKey: ord('0'); NextState: _state_readArrayTypePart; Action: TLR1.PushAndGo),
      (BeginKey: ord('1'); EndKey: ord('9'); NextState: _state_readArrayDecNumberSize; Action: TCTypeConverter.SelectArrayDecNumeralSystem),
      (BeginKey: ord(']'); EndKey: ord(']'); NextState: _state_readThirdTypePart; Action: TLR1.SkipAndGo),
      (BeginKey: ord(' '); EndKey: ord(' '); NextState: _state_readArrayTypePart; Action: TLR1.SkipAndGo),
      (BeginKey: $D; EndKey: $D; NextState: _state_readArrayTypePart; Action: TLR1.SkipAndGo),
      (BeginKey: $A; EndKey: $A; NextState: _state_readArrayTypePart; Action: TLR1.SkipAndGo),
      (BeginKey: $9; EndKey: $9; NextState: _state_readArrayTypePart; Action: TLR1.SkipAndGo)
      );
    _array_selectSizeNumeralSystem: array [0..4] of TKeyTransition = (
      (BeginKey: ord('0'); EndKey: ord('7'); NextState: _state_readArrayOctalNumberSize; Action: TCTypeConverter.SelectArrayOctalNumeralSystem),
      (BeginKey: ord('x'); EndKey: ord('x'); NextState: _state_readArrayHexNumberSize; Action: TCTypeConverter.SelectArrayHexNumeralSystem),
      (BeginKey: ord('b'); EndKey: ord('b'); NextState: _state_readArrayBinNumberSize; Action: TCTypeConverter.SelectArrayBinNumeralSystem),
      (BeginKey: ord(''''); EndKey: ord(''''); NextState: _state_readArrayOctalNumberSize; Action: TLR1.ExchangeAndGo), //c++ 14
      (BeginKey: ord(']'); EndKey: ord(']'); NextState: _state_readThirdTypePart; Action: TLR1.SkipAndGo)
      );
    _magazine_ArrayTypePart: array [0..1] of TMagazineTransition = (
      (BeginMagazine: ord('0'); EndMagazine: ord('0'); KeyTransitions: @TCTypeConverter._array_selectSizeNumeralSystem; KeyTransitionsLength: Length(TCTypeConverter._array_selectSizeNumeralSystem)),
      (BeginMagazine: 0; EndMagazine: _end; KeyTransitions: @TCTypeConverter._array_sizePart; KeyTransitionsLength: Length(TCTypeConverter._array_sizePart))
      );
    _array_sizeDecNumEnabled: array [0..6] of TKeyTransition = (
      (BeginKey: ord('0'); EndKey: ord('9'); NextState: _state_readArrayDecNumberSize; Action: TCTypeConverter.UpdateNumberArraySize),
      (BeginKey: ord(''''); EndKey: ord(''''); NextState: _state_readArrayDecNumberSize; Action: TLR1.PushAndGo), //c++ 14
      (BeginKey: ord(']'); EndKey: ord(']'); NextState: _state_readArrayEndSize; Action: TLR1.RepeatAtNewState),
      (BeginKey: ord(' '); EndKey: ord(' '); NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $D; EndKey: $D; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $A; EndKey: $A; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $9; EndKey: $9; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo)
      );
    _array_sizeDecNum: array [0..5] of TKeyTransition = (
      (BeginKey: ord('0'); EndKey: ord('9'); NextState: _state_readArrayDecNumberSize; Action: TCTypeConverter.UpdateNumberArraySize),
      (BeginKey: ord(']'); EndKey: ord(']'); NextState: _state_readArrayEndSize; Action: TLR1.RepeatAtNewState),
      (BeginKey: ord(' '); EndKey: ord(' '); NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $D; EndKey: $D; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $A; EndKey: $A; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $9; EndKey: $9; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo)
      );
    _magazine_arrayDecTypePart: array [0..1] of TMagazineTransition = (
      (BeginMagazine: ord(''''); EndMagazine: ord(''''); KeyTransitions: @TCTypeConverter._array_sizeDecNum; KeyTransitionsLength: Length(TCTypeConverter._array_sizeDecNum)),
      (BeginMagazine: 0; EndMagazine: _end; KeyTransitions: @TCTypeConverter._array_sizeDecNumEnabled; KeyTransitionsLength: Length(TCTypeConverter._array_sizeDecNumEnabled))
      );
    _array_sizeOctalNumEnabled: array [0..6] of TKeyTransition = (
      (BeginKey: ord('0'); EndKey: ord('7'); NextState: _state_readArrayOctalNumberSize; Action: TCTypeConverter.UpdateNumberArraySize),
      (BeginKey: ord(''''); EndKey: ord(''''); NextState: _state_readArrayOctalNumberSize; Action: TLR1.SkipAndGo), //c++ 14
      (BeginKey: ord(']'); EndKey: ord(']'); NextState: _state_readArrayEndSize; Action: TLR1.RepeatAtNewState),
      (BeginKey: ord(' '); EndKey: ord(' '); NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $D; EndKey: $D; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $A; EndKey: $A; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $9; EndKey: $9; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo)
      );
    _array_sizeOctalNum: array [0..5] of TKeyTransition = (
      (BeginKey: ord('0'); EndKey: ord('7'); NextState: _state_readArrayOctalNumberSize; Action: TCTypeConverter.UpdateNumberArraySize),
      (BeginKey: ord(']'); EndKey: ord(']'); NextState: _state_readArrayEndSize; Action: TLR1.RepeatAtNewState),
      (BeginKey: ord(' '); EndKey: ord(' '); NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $D; EndKey: $D; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $A; EndKey: $A; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $9; EndKey: $9; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo)
      );
    _magazine_arrayOctalTypePart: array [0..1] of TMagazineTransition = (
      (BeginMagazine: ord(''''); EndMagazine: ord(''''); KeyTransitions: @TCTypeConverter._array_sizeOctalNum; KeyTransitionsLength: Length(TCTypeConverter._array_sizeOctalNum)),
      (BeginMagazine: 0; EndMagazine: _end; KeyTransitions: @TCTypeConverter._array_sizeOctalNumEnabled; KeyTransitionsLength: Length(TCTypeConverter._array_sizeOctalNumEnabled))
      );
    _array_sizeBinNumEnabled: array [0..6] of TKeyTransition = (
      (BeginKey: ord('0'); EndKey: ord('1'); NextState: _state_readArrayBinNumberSize; Action: TCTypeConverter.UpdateNumberArraySize),
      (BeginKey: ord(''''); EndKey: ord(''''); NextState: _state_readArrayBinNumberSize; Action: TLR1.SkipAndGo), //c++ 14
      (BeginKey: ord(']'); EndKey: ord(']'); NextState: _state_readArrayEndSize; Action: TLR1.RepeatAtNewState),
      (BeginKey: ord(' '); EndKey: ord(' '); NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $D; EndKey: $D; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $A; EndKey: $A; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $9; EndKey: $9; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo)
      );
    _array_sizeBinNum: array [0..5] of TKeyTransition = (
      (BeginKey: ord('0'); EndKey: ord('1'); NextState: _state_readArrayBinNumberSize; Action: TCTypeConverter.UpdateNumberArraySize),
      (BeginKey: ord(']'); EndKey: ord(']'); NextState: _state_readArrayEndSize; Action: TLR1.RepeatAtNewState),
      (BeginKey: ord(' '); EndKey: ord(' '); NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $D; EndKey: $D; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $A; EndKey: $A; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $9; EndKey: $9; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo)
      );
    _magazine_arrayBinTypePart: array [0..1] of TMagazineTransition = (
      (BeginMagazine: ord(''''); EndMagazine: ord(''''); KeyTransitions: @TCTypeConverter._array_sizeBinNum; KeyTransitionsLength: Length(TCTypeConverter._array_sizeBinNum)),
      (BeginMagazine: 0; EndMagazine: _end; KeyTransitions: @TCTypeConverter._array_sizeBinNumEnabled; KeyTransitionsLength: Length(TCTypeConverter._array_sizeBinNumEnabled))
      );
    _array_sizeHexNumEnabled: array [0..8] of TKeyTransition = (
      (BeginKey: ord('0'); EndKey: ord('9'); NextState: _state_readArrayHexNumberSize; Action: TCTypeConverter.UpdateNumberArraySize),
      (BeginKey: ord('a'); EndKey: ord('f'); NextState: _state_readArrayHexNumberSize; Action: TCTypeConverter.UpdateHexNumberArraySize),
      (BeginKey: ord('A'); EndKey: ord('F'); NextState: _state_readArrayHexNumberSize; Action: TCTypeConverter.UpdateHexNumberArraySize),
      (BeginKey: ord(''''); EndKey: ord(''''); NextState: _state_readArrayHexNumberSize; Action: TLR1.SkipAndGo), //c++ 14
      (BeginKey: ord(']'); EndKey: ord(']'); NextState: _state_readArrayEndSize; Action: TLR1.RepeatAtNewState),
      (BeginKey: ord(' '); EndKey: ord(' '); NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $D; EndKey: $D; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $A; EndKey: $A; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $9; EndKey: $9; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo)
      );
    _array_sizeHexNum: array [0..7] of TKeyTransition = (
      (BeginKey: ord('0'); EndKey: ord('9'); NextState: _state_readArrayHexNumberSize; Action: TCTypeConverter.UpdateNumberArraySize),
      (BeginKey: ord('a'); EndKey: ord('f'); NextState: _state_readArrayHexNumberSize; Action: TCTypeConverter.UpdateHexNumberArraySize),
      (BeginKey: ord('A'); EndKey: ord('F'); NextState: _state_readArrayHexNumberSize; Action: TCTypeConverter.UpdateHexNumberArraySize),
      (BeginKey: ord(']'); EndKey: ord(']'); NextState: _state_readArrayEndSize; Action: TLR1.RepeatAtNewState),
      (BeginKey: ord(' '); EndKey: ord(' '); NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $D; EndKey: $D; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $A; EndKey: $A; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $9; EndKey: $9; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo)
      );
    _magazine_arrayHexTypePart: array [0..1] of TMagazineTransition = (
      (BeginMagazine: ord(''''); EndMagazine: ord(''''); KeyTransitions: @TCTypeConverter._array_sizeHexNum; KeyTransitionsLength: Length(TCTypeConverter._array_sizeHexNum)),
      (BeginMagazine: 0; EndMagazine: _end; KeyTransitions: @TCTypeConverter._array_sizeHexNumEnabled; KeyTransitionsLength: Length(TCTypeConverter._array_sizeHexNumEnabled))
      );
    _array_endSize: array [0..4] of TKeyTransition = (
      (BeginKey: ord(']'); EndKey: ord(']'); NextState: _state_readThirdTypePart; Action: TCTypeConverter.EndArraySize),
      (BeginKey: ord(' '); EndKey: ord(' '); NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $D; EndKey: $D; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $A; EndKey: $A; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo),
      (BeginKey: $9; EndKey: $9; NextState: _state_readArrayEndSize; Action: TLR1.SkipAndGo)
      );
    _magazine_arrayEndSizeTypePart: array [0..0] of TMagazineTransition = (
      (BeginMagazine: 0; EndMagazine: _end; KeyTransitions: @TCTypeConverter._array_endSize; KeyTransitionsLength: Length(TCTypeConverter._array_endSize))
      );
    {$endregion}

    _full: array [0..29] of TStateTransition = (
      (MagazineTransitions: @TCTypeConverter._magazine_typedef_0; MagazineTransitionsLength: Length(TCTypeConverter._magazine_typedef_0)),
      (MagazineTransitions: @TCTypeConverter._magazine_firstTypePart; MagazineTransitionsLength: Length(TCTypeConverter._magazine_firstTypePart)),
      (MagazineTransitions: @TCTypeConverter._magazine_Unsigned; MagazineTransitionsLength: Length(TCTypeConverter._magazine_Unsigned)),
      (MagazineTransitions: @TCTypeConverter._magazine_SignedOrStructOrShort; MagazineTransitionsLength: Length(TCTypeConverter._magazine_SignedOrStructOrShort)),
      (MagazineTransitions: @TCTypeConverter._magazine_customTypeName; MagazineTransitionsLength: Length(TCTypeConverter._magazine_customTypeName)),
      (MagazineTransitions: @TCTypeConverter._magazine_skip_spaces; MagazineTransitionsLength: Length(TCTypeConverter._magazine_skip_spaces)),
      (MagazineTransitions: @TCTypeConverter._magazine_ArrayTypePart; MagazineTransitionsLength: Length(TCTypeConverter._magazine_ArrayTypePart)),
      (MagazineTransitions: @TCTypeConverter._magazine_typedef_1; MagazineTransitionsLength: Length(TCTypeConverter._magazine_typedef_1)),
      (MagazineTransitions: @TCTypeConverter._magazine_Struct; MagazineTransitionsLength: Length(TCTypeConverter._magazine_Struct)),
      (MagazineTransitions: @TCTypeConverter._magazine_Signed; MagazineTransitionsLength: Length(TCTypeConverter._magazine_Signed)),
      (MagazineTransitions: @TCTypeConverter._magazine_Long; MagazineTransitionsLength: Length(TCTypeConverter._magazine_Long)),
      (MagazineTransitions: @TCTypeConverter._magazine_Int; MagazineTransitionsLength: Length(TCTypeConverter._magazine_Int)),
      (MagazineTransitions: @TCTypeConverter._magazine_Float; MagazineTransitionsLength: Length(TCTypeConverter._magazine_Float)),
      (MagazineTransitions: @TCTypeConverter._magazine_Double; MagazineTransitionsLength: Length(TCTypeConverter._magazine_Double)),
      (MagazineTransitions: @TCTypeConverter._magazine_Char_Const; MagazineTransitionsLength: Length(TCTypeConverter._magazine_Char_Const)),
      (MagazineTransitions: @TCTypeConverter._magazine_Unsigned2; MagazineTransitionsLength: Length(TCTypeConverter._magazine_Unsigned2)),
      (MagazineTransitions: @TCTypeConverter._magazine_Struct2; MagazineTransitionsLength: Length(TCTypeConverter._magazine_Struct2)),
      (MagazineTransitions: @TCTypeConverter._magazine_Short; MagazineTransitionsLength: Length(TCTypeConverter._magazine_Short)),
      (MagazineTransitions: @TCTypeConverter._magazine_SecondTypePart; MagazineTransitionsLength: Length(TCTypeConverter._magazine_SecondTypePart)),
      (MagazineTransitions: @TCTypeConverter._magazine_customName; MagazineTransitionsLength: Length(TCTypeConverter._magazine_customName)),
      (MagazineTransitions: @TCTypeConverter._magazine_ThirdTypePart; MagazineTransitionsLength: Length(TCTypeConverter._magazine_ThirdTypePart)),
      (MagazineTransitions: @TCTypeConverter._magazine_arrayDecTypePart; MagazineTransitionsLength: Length(TCTypeConverter._magazine_arrayDecTypePart)),
      (MagazineTransitions: @TCTypeConverter._magazine_arrayHexTypePart; MagazineTransitionsLength: Length(TCTypeConverter._magazine_arrayHexTypePart)),
      (MagazineTransitions: @TCTypeConverter._magazine_arrayBinTypePart; MagazineTransitionsLength: Length(TCTypeConverter._magazine_arrayBinTypePart)),
      (MagazineTransitions: @TCTypeConverter._magazine_arrayOctalTypePart; MagazineTransitionsLength: Length(TCTypeConverter._magazine_arrayOctalTypePart)),
      (MagazineTransitions: @TCTypeConverter._magazine_arrayEndSizeTypePart; MagazineTransitionsLength: Length(TCTypeConverter._magazine_arrayEndSizeTypePart)),
      (MagazineTransitions: @TCTypeConverter._magazine_void; MagazineTransitionsLength: Length(TCTypeConverter._magazine_void)),
      (MagazineTransitions: @TCTypeConverter._magazine_Char; MagazineTransitionsLength: Length(TCTypeConverter._magazine_Char)),
      (MagazineTransitions: @TCTypeConverter._magazine_Const; MagazineTransitionsLength: Length(TCTypeConverter._magazine_Const)) ,
      (MagazineTransitions: @TCTypeConverter._magazine_ConstPointer; MagazineTransitionsLength: Length(TCTypeConverter._magazine_ConstPointer))
      );
    function GetObjectInfo(Index: Integer): TTypedObject;
    function GetObjectsCount: Integer;
    function GetTypeInfo(Index: Integer): PTypedObject;
    function GetTypesCount: Integer;
    function AddConvertedType(const AType: TTypedObject): string;
    function GetTypeInfoByName(Index: string): PTypedObject;
  public
    {$IFDEF UnitTests}
    DefinedObject: TParsedTypedObjectGroup;
    {$ENDIF}
    CurrentStructData: array of TParsedTypedObject;
    property TypesCount: Integer read GetTypesCount;
    property TypeInfo[Index: Integer]: PTypedObject read GetTypeInfo;
    property TypeInfoByName[Index: string]: PTypedObject read GetTypeInfoByName;
    property TypesDictionary: TDictionary<string, Integer> read FTypesDictionary;
    property ObjectsCount: Integer read GetObjectsCount;
    property ObjectInfo[Index: Integer]: TTypedObject read GetObjectInfo;
    property ObjectsDictionary: TDictionary<string, Integer> read FObjectsDictionary;
    constructor Create;
    destructor Destroy; override;
    procedure ClearObjectsAndTypes;
    procedure RunParse(const AString: string);
    procedure AddParsed(const AString: string);
  end;

function IndexOf(const arr: TArray<string>; const value: string): Integer; overload;
function IndexOf(const arr: TArray<TCommand>; const Name: string): Integer; overload;
function IndexOf(const arr: TArray<TEnum>; const Name: string): Integer; overload;
function IndexOf(const arr: TArray<TEnumGroup>; const Name: string): Integer; overload;
function IndexOf(const arr: TArray<TType>; const Name: string): Integer; overload;
function ConvertDefaultName(const Name: string): string;
function GroupAsEnumOrSet(const Group: string): Boolean;

const
    OrdinalTypes: array [0..4, Boolean] of string = (
        ('Byte', 'ShortInt'),
        ('Word', 'SmallInt'),
        ('LongWord', 'LongInt'),
        ('UInt64', 'Int64'),
        ('{$IFDEF CPUX64}UInt64{$ELSE}LongWord{$ENDIF}', '{$IFDEF CPUX64}Int64{$ELSE}LongInt{$ENDIF}')
      );

implementation

function GroupAsEnumOrSet(const Group: string): Boolean;
begin
  Result:= (Group <> '') and (Group <> 'Boolean');
end;

function ConvertDefaultName(const Name: string): string;
begin
  if Name = '' then
    Result:= ''
  else if Name = 'HANDLE' then
    Result:= 'THandle'
  else if Name = 'LPVOID' then
    Result:= 'Pointer'
  else if Name = 'FLOAT' then
    Result:= 'Single'
  else if (StrIComp(PChar(Pointer(Name)), 'type') = 0) or
      (StrIComp(PChar(Pointer(Name)), 'var') = 0) or
      (StrIComp(PChar(Pointer(Name)), 'function') = 0) or
      (StrIComp(PChar(Pointer(Name)), 'procedure') = 0) or
      (StrIComp(PChar(Pointer(Name)), 'property') = 0) or
      (StrIComp(PChar(Pointer(Name)), 'object') = 0) or
      (StrIComp(PChar(Pointer(Name)), 'packed') = 0) or
      (StrIComp(PChar(Pointer(Name)), 'label') = 0) or
      (StrIComp(PChar(Pointer(Name)), 'in') = 0) or
      (StrIComp(PChar(Pointer(Name)), 'as') = 0) or
      (StrIComp(PChar(Pointer(Name)), 'is') = 0) or
      (StrIComp(PChar(Pointer(Name)), 'program') = 0) or
      (StrIComp(PChar(Pointer(Name)), 'array') = 0) or
      (StrIComp(PChar(Pointer(Name)), 'unit') = 0) or
      (StrIComp(PChar(Pointer(Name)), 'string') = 0) or
      (StrIComp(PChar(Pointer(Name)), 'const') = 0) or
      (StrIComp(PChar(Pointer(Name)), 'end') = 0) or
      (StrIComp(PChar(Pointer(Name)), 'begin') = 0) then
    Result:= '_' + Name
  else
    Result:= Name;
end;

function IndexOf(const arr: TArray<string>; const value: string): Integer;
var i: Integer;
begin
  for i := 0 to High(arr) do
    if arr[i] = value then
      Exit(i);
  Result:= -1;
end;

function IndexOf(const arr: TArray<TCommand>; const Name: string): Integer;
var i: Integer;
begin
  for i := 0 to High(arr) do
    if arr[i].Name.Name = Name then
      Exit(i);
  Result:= -1;
end;

function IndexOf(const arr: TArray<TType>; const Name: string): Integer;
var i: Integer;
begin
  for i := 0 to High(arr) do
    if arr[i].Name = Name then
      Exit(i);
  Result:= -1;
end;

function IndexOf(const arr: TArray<TEnum>; const Name: string): Integer;
var i: Integer;
begin
  for i := 0 to High(arr) do
    if arr[i].Name = Name then
      Exit(i);
  Result:= -1;
end;

function IndexOf(const arr: TArray<TEnumGroup>; const Name: string): Integer;
var i: Integer;
begin
  for i := 0 to High(arr) do
    if arr[i].GroupName = Name then
      Exit(i);
  Result:= -1;
end;

{ TOGLLoader }

constructor TOGLLoader.Create;
begin
  EnumReader.CurrentGroupIndex:= -1;
  EnumReader.Owner:= Self;
  ExtensionReader.Owner:= Self;
  TypesReader.Owner:= Self;
  CommadsReader.Owner:= Self;
end;

destructor TOGLLoader.Destroy;
begin
  inherited;
end;

function TOGLLoader.NewElement(const ElementName: string;
  ParseOptions: PXMLElementParserOptions; Root: Pointer): Pointer;
var v: TOGLExtension;
begin
  Result:= nil;
  if Integer(Root) = 1 then begin
    if ElementName = 'enums' then
      EnumReader.InitEnumsOptions(ParseOptions)
    else if ElementName = 'groups' then
      EnumReader.InitGroupsOptions(ParseOptions)
    else if ElementName = 'feature' then
      ExtensionReader.InitFeatureOptions(ParseOptions)
    else if ElementName = 'extensions' then
      ExtensionReader.InitExtensionsOptions(ParseOptions)
    else if ElementName = 'types' then
      TypesReader.InitOptions(ParseOptions)
    else if ElementName = 'commands' then
      CommadsReader.InitOptions(ParseOptions);
  end else if ElementName = 'registry' then begin
    Integer(Result):= 1;
    ParseOptions.OnNewInnerElement:= NewElement;
  end;
end;

{ TEnumReader }

procedure TEnumReader.CloseEnum(Element: Pointer);
var i, j: Integer;
    a: TArray<string>;
  k: Integer;
begin
  i:= Owner.Data.IndexOfEnum(Enum.Name);
  if i <> -1 then begin
    if Owner.Data.Enums[i].Value = '' then
      Owner.Data.Enums[i].Value:= Enum.Value;
    if Owner.Data.Enums[i].Comment = '' then
      Owner.Data.Enums[i].Comment:= Enum.Comment;
    if Owner.Data.Enums[i].Alias = '' then
      Owner.Data.Enums[i].Alias:= Enum.Alias;
  end else begin
    i:= Length(Owner.Data.Enums);
    SetLength(Owner.Data.Enums, i + 1);
    Owner.Data.Enums[i]:= Enum;
  end;
  if CurrentGroupIndex <> -1 then
    InsertEnumInGroup(CurrentGroupIndex);
  a:= Enum.Group.Split([',']);
  for k := 0 to High(a) do
    if a[k] <> Group.GroupName then
      InsertEnumInGroup(a[k]);
  Finalize(Enum);
end;

procedure TEnumReader.CloseParentElement(Element: Pointer);
begin
  Finalize(Group);
  Group.IsSet:= False;
  CurrentGroupIndex:= -1;
end;

procedure TEnumReader.EnumNewAttribute(const AttributeName,
  AttributeValue: string; Element: Pointer);
begin
  if AttributeName = 'name' then
    Enum.Name:= AttributeValue
  else if AttributeName = 'value' then
    Enum.Value:= AttributeValue
  else if AttributeName = 'comment' then
    Enum.Comment:= AttributeValue
  else if AttributeName = 'alias' then
    Enum.Alias:= AttributeValue
  else if AttributeName = 'group' then
    Enum.Group:= AttributeValue
end;

procedure TEnumReader.EnumsNewAttribute(const AttributeName,
  AttributeValue: string; Element: Pointer);
begin
  if AttributeName = 'group' then
    Group.GroupName:= AttributeValue
  else if AttributeName = 'type' then
    Group.IsSet:= AttributeValue = 'bitmask'
  else if AttributeName = 'comment' then
    Group.Comment:= AttributeValue;
end;

procedure TEnumReader.GroupNewAttribute(const AttributeName,
  AttributeValue: string; Element: Pointer);
begin
  if AttributeName = 'name' then
    Group.GroupName:= AttributeValue
  else if AttributeName = 'comment' then
    Group.Comment:= AttributeValue;
end;

function TEnumReader.GroupsNewElement(const ElementName: string;
  ParseOptions: PXMLElementParserOptions; Root: Pointer): Pointer;
begin
  if ElementName = 'group' then begin
    ParseOptions.OnNewAttribute:= GroupNewAttribute;
    ParseOptions.OnNewInnerElement:= NewElement;
    ParseOptions.OnCloseElement:= CloseParentElement;
  end;
end;

procedure TEnumReader.InitEnumsOptions(ParseOptions: PXMLElementParserOptions);
begin
  ParseOptions.OnNewAttribute:= EnumsNewAttribute;
  ParseOptions.OnNewInnerElement:= NewElement;
  ParseOptions.OnCloseElement:= CloseParentElement;
end;

procedure TEnumReader.InitGroupsOptions(ParseOptions: PXMLElementParserOptions);
begin
  ParseOptions.OnNewInnerElement:= GroupsNewElement;
end;

procedure TEnumReader.InsertEnumInGroup(GroupIndex: Integer);
var j: Integer;
begin
  j:= IndexOf(Owner.Data.EnumGroups[GroupIndex].Enums, Enum.Name);
  if j = -1 then begin
    SetLength(Owner.Data.EnumGroups[GroupIndex].Enums, Length(Owner.Data.EnumGroups[GroupIndex].Enums) + 1);
    Owner.Data.EnumGroups[GroupIndex].Enums[High(Owner.Data.EnumGroups[GroupIndex].Enums)]:= Enum.Name;
  end;
end;

procedure TEnumReader.InsertEnumInGroup(const GroupName: string);
var g: Integer;
begin
  g:= Owner.Data.IndexOfEnumGroup(GroupName);
  if g = -1 then begin
    g:= Length(Owner.Data.EnumGroups);
    SetLength(Owner.Data.EnumGroups, g + 1);
    Owner.Data.EnumGroups[g].GroupName:= GroupName;
  end;
  InsertEnumInGroup(g);
end;

function TEnumReader.NewElement(const ElementName: string;
  ParseOptions: PXMLElementParserOptions; Root: Pointer): Pointer;
var j: Integer;
begin
  if (CurrentGroupIndex = -1) and (Group.GroupName <> '') then begin
    j:= Owner.Data.IndexOfEnumGroup(Group.GroupName);
    if j = -1 then begin
      j:= Length(Owner.Data.EnumGroups);
      SetLength(Owner.Data.EnumGroups, j + 1);
      Owner.Data.EnumGroups[j]:= Group;
    end else begin
      Owner.Data.EnumGroups[j].IsSet:= Group.IsSet;
      if (Owner.Data.EnumGroups[j].Comment <> '') and (Group.Comment <> '') then
        Owner.Data.EnumGroups[j].Comment:= Group.Comment;
    end;
    CurrentGroupIndex:= j;
  end;
  if ElementName = 'enum' then begin
    ParseOptions.OnNewAttribute:= EnumNewAttribute;
    ParseOptions.OnCloseElement:= CloseEnum;
  end;
  Result:= nil;
end;

{ TParsedData }

function TParsedData.IndexOfCommand(const Name: string): Integer;
var i: Integer;
begin
  for i := 0 to High(Commands) do
    if Commands[i].Name.Name = Name then
      Exit(i);
  Result:= -1;
end;

function TParsedData.IndexOfEnum(const Name: string): Integer;
var i: Integer;
begin
  for i := 0 to High(Enums) do
    if Enums[i].Name = Name then
      Exit(i);
  Result:= -1;
end;

function TParsedData.IndexOfEnumGroup(const Name: string): Integer;
var i: Integer;
begin
  for i := 0 to High(EnumGroups) do
    if EnumGroups[i].GroupName = Name then
      Exit(i);
  Result:= -1;
end;

function TParsedData.IndexOfType(const Name: string): Integer;
var i: Integer;
begin
  if Name <> '' then
  for i := 0 to High(Types) do
    if (Types[i].Name = Name) or
        (Types[i].Name.StartsWith('struct ') and
          (StrComp(PChar(@Types[i].Name[8]), PChar(Name)) = 0)) then
      Exit(i);
  Result:= -1;
end;

{ TExtensionReader }

procedure TExtensionReader.CloseElement(Element: Pointer);
begin
  SetLength(Owner.Data.Extensions, Length(Owner.Data.Extensions) + 1);
  Owner.Data.Extensions[High(Owner.Data.Extensions)]:= Current;
  Finalize(Current);
end;

procedure TExtensionReader.CloseRequirementElement(Element: Pointer);
begin
  case Integer(Element) of
    1: begin
      SetLength(Current.Require, Length(Current.Require) + 1);
      Current.Require[High(Current.Require)]:= CurrentRequire;
    end;
    3: begin
      SetLength(Current.Remove, Length(Current.Remove) + 1);
      Current.Remove[High(Current.Remove)]:= CurrentRequire;
    end;
  end;
  Finalize(CurrentRequire);
end;

procedure TExtensionReader.InitExtensionsOptions(
  ParseOptions: PXMLElementParserOptions);
begin
  ParseOptions.OnNewInnerElement:= NewExtensionElement;
end;

procedure TExtensionReader.InitFeatureOptions(
  ParseOptions: PXMLElementParserOptions);
begin
  ParseOptions.OnNewInnerElement:= NewElement;
  ParseOptions.OnNewAttribute:= NewFeatureAttribute;
  ParseOptions.OnCloseElement:= CloseElement;
end;

function TExtensionReader.NewElement(const ElementName: string;
  ParseOptions: PXMLElementParserOptions; Root: Pointer): Pointer;
begin
  Result:= nil;
  if ElementName = 'require' then begin
    ParseOptions.OnNewInnerElement:= NewRequireElement;
    ParseOptions.OnNewAttribute:= NewRequireAttribute;
    ParseOptions.OnCloseElement:= CloseRequirementElement;
    Result:= Pointer(1);
  end else if ElementName = 'remove' then begin
    ParseOptions.OnNewInnerElement:= NewRequireElement;
    ParseOptions.OnNewAttribute:= NewRequireAttribute;
    ParseOptions.OnCloseElement:= CloseRequirementElement;
    Result:= Pointer(2);
  end;
end;

procedure TExtensionReader.NewExtensionAttribute(const AttributeName,
  AttributeValue: string; Element: Pointer);
begin
  if AttributeName = 'name' then
    Current.Name:= AttributeValue
  else if AttributeName = 'supported' then
    Current.Supported:= AttributeValue.Split(['|'])
end;

function TExtensionReader.NewExtensionElement(const ElementName: string;
  ParseOptions: PXMLElementParserOptions; Root: Pointer): Pointer;
begin
  if ElementName = 'extension' then begin
    ParseOptions.OnNewInnerElement:= NewElement;
    ParseOptions.OnNewAttribute:= NewExtensionAttribute;
    ParseOptions.OnCloseElement:= CloseElement;
  end;
end;

procedure TExtensionReader.NewFeatureAttribute(const AttributeName,
  AttributeValue: string; Element: Pointer);
begin
  if AttributeName = 'name' then
    Current.Name:= AttributeValue
  else if AttributeName = 'api' then
    Current.Supported:= AttributeValue.Split(['|']);
end;

procedure TExtensionReader.NewRequireAttribute(const AttributeName,
  AttributeValue: string; Element: Pointer);
begin
  case Integer(Element) of
    0: if AttributeName = 'comment' then begin
      CurrentRequire.Comment:= AttributeValue;
    end else if AttributeName = 'profile' then begin
      CurrentRequire.Supported:= AttributeValue;
    end;
    1: if AttributeName = 'name' then begin
      SetLength(CurrentRequire.Enums, Length(CurrentRequire.Enums) + 1);
      CurrentRequire.Enums[High(CurrentRequire.Enums)]:= AttributeValue;
    end;
    2: if AttributeName = 'name' then begin
      SetLength(CurrentRequire.Commands, Length(CurrentRequire.Commands) + 1);
      CurrentRequire.Commands[High(CurrentRequire.Commands)]:= AttributeValue;
    end;
  end;
end;

function TExtensionReader.NewRequireElement(const ElementName: string;
  ParseOptions: PXMLElementParserOptions; Root: Pointer): Pointer;
begin
  if ElementName = 'enum' then begin
    ParseOptions.OnNewAttribute:= NewRequireAttribute;
    Result:= Pointer(1);
  end else if ElementName = 'command' then begin
    ParseOptions.OnNewAttribute:= NewRequireAttribute;
    Result:= Pointer(2);
  end;
end;

{ TTypesReader }

procedure TTypesReader.CloseElement(Element: Pointer);
begin
  SetLength(Owner.Data.Types, Length(Owner.Data.Types) + 1);
  Owner.Data.Types[High(Owner.Data.Types)]:= Current;
  Finalize(Current);
  Current.IsApientry:= False;
end;

procedure TTypesReader.InitOptions(ParseOptions: PXMLElementParserOptions);
begin
  ParseOptions.OnNewInnerElement:= NewElement;
end;

procedure TTypesReader.NewAttribute(const AttributeName, AttributeValue: string;
  Element: Pointer);
begin
  if AttributeName = 'name' then
    Current.Name:= AttributeValue
  else if AttributeName = 'requires' then
    Current.RequiredType:= AttributeValue;
end;

function TTypesReader.NewElement(const ElementName: string;
  ParseOptions: PXMLElementParserOptions; Root: Pointer): Pointer;
begin
  ParseOptions.OnCloseElement:= CloseElement;
  ParseOptions.OnNewInnerElement:= NewElementLikeAttribute;
  ParseOptions.OnText:= NewText;
  ParseOptions.OnNewAttribute:= NewAttribute;
end;

function TTypesReader.NewElementLikeAttribute(const ElementName: string;
  ParseOptions: PXMLElementParserOptions; Root: Pointer): Pointer;
begin
  if ElementName = 'apientry' then
    Current.IsApientry:= True
  else if ElementName = 'name' then begin
    ParseOptions.OnText:= NewTextName;
  end;
end;

procedure TTypesReader.NewText(const Value: string; Element: Pointer);
begin
  Current.FullText:= Current.FullText + Value;
end;

procedure TTypesReader.NewTextName(const Value: string; Element: Pointer);
begin
  Current.Name:= Value;
  NewText(Value, Element);
end;

{ TCommandsReader }

procedure TCommandsReader.CloseElement(Element: Pointer);
begin
  case Integer(Element) of
    1: begin
      SetLength(Owner.Data.Commands, Length(Owner.Data.Commands) + 1);
      Owner.Data.Commands[High(Owner.Data.Commands)]:= Current;
      Finalize(Current);
    end;
    3: begin
      SetLength(Current.Params, Length(Current.Params) + 1);
      Current.Params[High(Current.Params)]:= CurrentParam;
      Finalize(CurrentParam);
    end;
  end;
end;

procedure TCommandsReader.InitOptions(ParseOptions: PXMLElementParserOptions);
begin
  ParseOptions.OnNewInnerElement:= NewElement;
end;

procedure TCommandsReader.NewAttribute(const AttributeName,
  AttributeValue: string; Element: Pointer);
begin
  case Integer(Element) of
    2: if AttributeName = 'group' then begin
      Current.Name.Group:= AttributeValue;
    end;
    3: if AttributeName = 'len' then begin
      CurrentParam.Length:= AttributeValue
    end else if AttributeName = 'group' then begin
      CurrentParam.Group:= AttributeValue;
    end;
    4: if AttributeName = 'name' then begin
      SetLength(Current.Aliases, Length(Current.Aliases) + 1);
      Current.Aliases[High(Current.Aliases)]:= AttributeValue;
    end;
  end;
end;

function TCommandsReader.NewElement(const ElementName: string;
  ParseOptions: PXMLElementParserOptions; Root: Pointer): Pointer;
begin
  Result:= nil;
  case Integer(Root) of
    0: if ElementName = 'command' then begin
      ParseOptions.OnNewAttribute:= NewAttribute;
      ParseOptions.OnText:= NewText;
      ParseOptions.OnNewInnerElement:= NewElement;
      ParseOptions.OnCloseElement:= CloseElement;
      Result:= Pointer(1);
    end;
    1: if ElementName = 'proto' then begin
      ParseOptions.OnNewAttribute:= NewAttribute;
      ParseOptions.OnText:= NewText;
      ParseOptions.OnNewInnerElement:= NewElement;
      //ParseOptions.OnCloseElement:= CloseElement;
      Result:= Pointer(2);
    end else if ElementName = 'param' then begin
      ParseOptions.OnNewAttribute:= NewAttribute;
      ParseOptions.OnText:= NewText;
      ParseOptions.OnNewInnerElement:= NewElement;
      ParseOptions.OnCloseElement:= CloseElement;
      Result:= Pointer(3);
    end else if ElementName = 'alias' then begin
      ParseOptions.OnNewAttribute:= NewAttribute;
      ParseOptions.OnNewInnerElement:= NewElement;
      //ParseOptions.OnCloseElement:= CloseElement;
      Result:= Pointer(4);
    end;
    2, 3: if ElementName = 'ptype' then begin
      //ParseOptions.OnNewAttribute:= NewAttribute;
      ParseOptions.OnText:= NewText;
      //ParseOptions.OnNewInnerElement:= NewElement;
      //ParseOptions.OnCloseElement:= CloseElement;
      Result:= Pointer(Integer(Root) + 3);
    end else if ElementName = 'name' then begin
      //ParseOptions.OnNewAttribute:= NewAttribute;
      ParseOptions.OnText:= NewText;
      //ParseOptions.OnNewInnerElement:= NewElement;
      //ParseOptions.OnCloseElement:= CloseElement;
      Result:= Pointer(Integer(Root) + 5);
    end;
  end;
end;

procedure TCommandsReader.NewText(const Value: string; Element: Pointer);
begin
  case Integer(Element) of
    2: Current.Name.FullText:= Current.Name.FullText + Value;
    3: CurrentParam.FullText:= CurrentParam.FullText + Value;
    5: begin
      Current.Name.InType:= Value;
      Current.Name.FullText:= Current.Name.FullText + Value;
    end;
    6: begin
      CurrentParam.InType:= Value;
      CurrentParam.FullText:= CurrentParam.FullText + Value;
    end;
    7: begin
      Current.Name.Name:= Value;
      Current.Name.FullText:= Current.Name.FullText + Value;
    end;
    8: begin
      CurrentParam.Name:= Value;
      CurrentParam.FullText:= CurrentParam.FullText + Value;
    end;
  end;
end;

{ TPascalSaver }

function TPascalSaver.ConvertDefaultCTypeToDelphiEquivalent(
  FullText: PChar): AnsiString;
begin

end;

destructor TPascalSaver.Destroy;
begin
  Prepared.Finalize(False);
  FreeAndNil(FConverter);
  inherited;
end;

procedure TPascalSaver.GenerateAPTypeDeclaration(const AParent: AnsiString;
  indexes: TArray<TArray<TAPData>>; isGroup: Boolean);
var txt, curType: AnsiString;
    l, k: Integer;
begin
  for l := 0 to High(indexes) do begin
    curType:= '';
    for k := 0 to High(indexes[l]) - 2 do
      curType:= indexes[l][k].GenerateName(curType);
    if Length(indexes[l]) > 1 then
      curType:= indexes[l][High(indexes[l]) - 1].GenerateName(AParent + curType)
    else
      curType:= AParent;
    if indexes[l][High(indexes[l])].PointerCount > 0 then begin
      if (curType = 'GLchar') or (curType = 'GLcharARB') then
        txt:= '  P' + curType + ' = PAnsiChar;' + sLineBreak
      else if isGroup then
        txt:= '  P' + curType + ' = ^T' + curType + ';' + sLineBreak
      else
        txt:= '  P' + curType + ' = ^' + curType + ';' + sLineBreak;
      OutStream.Write(Pointer(txt)^, Length(txt));
      for k := 2 to indexes[l][High(indexes[l])].PointerCount do begin
        txt:= '  ' + StringOfChar('P', k) + curType +
            ' = ^' + StringOfChar('P', k - 1) + curType +
            ';' + sLineBreak;
        OutStream.Write(Pointer(txt)^, Length(txt));
      end;
    end;

    if indexes[l][High(indexes[l])].ArraySpecific <> nil then begin
      txt:= '  ' + indexes[l][High(indexes[l])].GenerateName(curType) + ' = ' +
          indexes[l][High(indexes[l])].GetArrayTypeDef + StringOfChar('P', indexes[l][High(indexes[l])].PointerCount) +
          curType + ';' + sLineBreak;
      OutStream.Write(Pointer(txt)^, Length(txt));
    end;
  end;
end;

function TPascalSaver.GenerateCType(const TypeDeclaration: TParam): string;
var e: Integer;
    t: string;
    isConst: Integer;
    i, k: Integer;
    o: TTypedObject;
begin
  t:= GetRealTypeName(TypeDeclaration.InType);
  if GroupAsEnumOrSet(TypeDeclaration.Group) then begin
    e:= LoadedData[Prepared.CurrentData].IndexOfEnumGroup(TypeDeclaration.Group);
    if (e <> -1) and Prepared.EnumGroups.Using[Prepared.groupsOffset + e] then
      t:= TypeDeclaration.Group;
  end;
  if t = '' then begin
    FConverter.RunParse(TypeDeclaration.FullText);
    if FConverter.ObjectsCount = 1 then begin
      o:= FConverter.ObjectInfo[0];
      Result:= ConvertDefaultName(o.Name) + ': ';
      case Length(o.APSpecific) of
        0: Result:= ConvertDefaultName(o.ToPascalName(Result, False));
      else
        for i := 0 to High(o.APSpecific) do
          if Length(o.APSpecific[i].ArraySpecific) > 0 then
            raise Exception.Create('Wrong type');
        Result:= ConvertDefaultName(o.ToPascalName(Result, False));
      end;
    end else
      raise Exception.Create('Wrong type');
  end else begin
    e:= GetPointerLevel(TypeDeclaration.FullText);
    Result:= ConvertDefaultName(TypeDeclaration.Name) + ': ';
    if e > 0 then begin
      if t = 'THandle' then
        t:= 'Handle';
      Result:= Result + StringOfChar('P', e) + t;
    end else if TypeDeclaration.Group <> t then
      Result:= Result + t
    else
      Result:= Result + 'T' + t;
  end;
end;

function TPascalSaver.GenerateDelphiType(const TypeDeclaration: TParam): string;
var i: Integer;
    l, e: LongWord;
    t: string;
    isConst: Boolean;
    t2: TTypedObject;
begin
  //FConverter.RunParse(TypeDeclaration.FullText);
  //Assert(FConverter.ObjectsCount = 1);
  //t2:= FConverter.ObjectInfo[0];
  if TypeDeclaration.InType <> '' then begin
    if TypeDeclaration.Length <> '' then begin
      val(TypeDeclaration.Length, l, e);
      if e <> 0 then
        l:= 0;
    end else
      l:= 0;
    if l > 1 then begin
      if TypeDeclaration.InType <> '' then
        t:= ConvertDefaultName(TypeDeclaration.InType)
      else
        raise Exception.Create('Wrong pointer type');
      if GroupAsEnumOrSet(TypeDeclaration.Group) then begin
        e:= LoadedData[Prepared.CurrentData].IndexOfEnumGroup(TypeDeclaration.Group);
        if (e <> -1) and Prepared.EnumGroups.Using[Prepared.groupsOffset + e] then
          t:= 'T' + ConvertDefaultName(TypeDeclaration.Group);
      end;
      e:= GetPointerLevel(TypeDeclaration.FullText);
      if e = 0 then
        raise Exception.Create('Wrong pointer level')
      else
        Dec(e);

      if (e > 0) and (t = 'THandle') then
        t:= 'Handle';

      isConst:= TypeDeclaration.FullText.StartsWith('const');
      if isConst then
        Result:= 'const ' + ConvertDefaultName(TypeDeclaration.Name) + ': '
      else
        Result:= 'var ' + ConvertDefaultName(TypeDeclaration.Name) + ': ';

      Result:= Result + StringOfChar('P', e) + t + IntToStr(l) + 'v';
      Exit;
    end else begin
      e:= GetPointerLevel(TypeDeclaration.FullText);
      if (e > 0) and (t = 'THandle') then
        t:= 'Handle';
      if (e = 1) and (l = 1) then begin
        isConst:= TypeDeclaration.FullText.StartsWith('const');
        if isConst then
          Result:= 'const ' + ConvertDefaultName(TypeDeclaration.Name) + ': '
        else
          Result:= 'var ' + ConvertDefaultName(TypeDeclaration.Name) + ': ';

        t:= GetRealTypeName(TypeDeclaration.InType);
        if GroupAsEnumOrSet(TypeDeclaration.Group) then begin
          e:= LoadedData[Prepared.CurrentData].IndexOfEnumGroup(TypeDeclaration.Group);
          if (e <> -1) and Prepared.EnumGroups.Using[Prepared.groupsOffset + e] then
            t:= 'T' + ConvertDefaultName(TypeDeclaration.Group);
        end;

        Result:= Result + t;
        Exit;
      end;
    end;
  end;
  Result:= GenerateCType(TypeDeclaration);
end;

procedure TPascalSaver.GenerateDynamicExtensions(const AOptions: TGeneratorOptions);
var i, j, k, l: Integer;
    txt: AnsiString;
begin
  for k := 0 to High(LoadedData) do
    for l := 0 to High(LoadedData[k].Extensions) do
      if AOptions.Selection[k][l] = cuDynamic then begin
        txt:= '    ' + LoadedData[k].Extensions[l].Name;
        OutStream.Write(Pointer(txt)^, Length(txt));

        for j := l + 1 to High(LoadedData[k].Extensions) do
          if AOptions.Selection[k][j] = cuDynamic then begin
            txt:= ',' + sLineBreak + '    ' + LoadedData[k].Extensions[j].Name;
            OutStream.Write(Pointer(txt)^, Length(txt));
          end;

        for i := k + 1 to High(LoadedData) do
          for j := 0 to High(LoadedData[i].Extensions) do
            if AOptions.Selection[i][j] = cuDynamic then begin
              txt:= ',' + sLineBreak + '    ' + LoadedData[i].Extensions[j].Name;
              OutStream.Write(Pointer(txt)^, Length(txt));
            end;
        Exit;
      end;
end;

function TPascalSaver.GenerateParamsCStyle(const Command: TCommand; const Info: TCommandInfo): string;
var i: Integer;
begin
  Result:= '';
  if Length(Command.Params) = 0 then
    Exit;

  Result:= '(' + ConvertDefaultName(Command.Params[0].Name) + ': ' + Info.Params[0];
  for i := 1 to High(Command.Params) do
    Result:= Result + '; ' + ConvertDefaultName(Command.Params[i].Name) + ': ' + Info.Params[i];
  Result:= Result + ')';
end;

function TPascalSaver.GenerateParamsWithDelphiTypes(
  const Command: TCommand): string;
var i: Integer;
begin
  Result:= '';
  if Length(Command.Params) = 0 then
    Exit;

  Result:= '(' + GenerateDelphiType(Command.Params[0]);
  for i := 1 to High(Command.Params) do
    Result:= Result + '; ' + GenerateDelphiType(Command.Params[i]);
  Result:= Result + ')';
end;

function TPascalSaver.GetPointerLevel(const typeDefine: string): Integer;
var i: Integer;
begin
  Result:= 0;
  for i:= 1 to Length(typeDefine) do
    if typeDefine[i] = '*' then
      Inc(Result);
end;

function TPascalSaver.GetRealTypeName(const Name: string): string;
var i: Integer;
    temp: AnsiString;
begin
  i:= LoadedData[0].IndexOfType(Name);
  if (i <> -1) and Prepared.extendedTypeNames.TryGetValue(i, temp) then
    Result:= temp
  else
    Result:= ConvertDefaultName(Name);
end;

procedure TPascalSaver.InitializeCommandsParams(const AData: TParsedData;
  const AOptions: TGeneratorOptions);
  function FixType(const t: TTypedObject; var AName: AnsiString): Integer;
  begin
    Result:= AData.IndexOfType(t.ParentType);
    if Result <> -1 then begin
      SetTypeUsing(AData, Result);
      AName:= t.ToPascalName('', False);
      if AName = 'VOID' then
        AName:= ''
      else begin
        if t.ParentType <> AData.Types[Result].Name then
          Prepared.extendedTypeNames.AddOrSetValue(Result + Prepared.typesOffset, t.ParentType);

        if t.APSpecific <> nil then
          Prepared.TypesInfo.AddAP(Prepared.typesOffset + Result, t.GetAPInfo);
      end;
    end else if (t.StandardType = stVoid) and (Length(t.APSpecific) = 0) then
      AName:= ''
    else
      AName:= t.ToPascalName('', False);
  end;
var j, k, m: Integer;
    indexes: TArray<Integer>;
    typeIndex, fix, groupIndex, index: Integer;
    t: TTypedObject;
begin
  for index:= 0 to High(AData.Commands) do
  if Prepared.neededCommands[index + Prepared.commandsOffset].CommandUsing <> cuNone then begin
    //Prepared.neededCommands[index + Prepared.commandsOffset].ResultType:= GenerateCType(AData.Commands[index].Name);
    if AData.Commands[Index].Name.Group = 'String' then
      Prepared.neededCommands[index + Prepared.commandsOffset].ResultType:= 'PAnsiChar'
    else begin
      FConverter.RunParse(AData.Commands[index].Name.FullText);
      Assert(FConverter.ObjectsCount = 1);
      FixType(FConverter.ObjectInfo[0], Prepared.neededCommands[index + Prepared.commandsOffset].ResultType);
    end;
    {typeIndex:= AData.IndexOfType(AData.Commands[index].Name.InType);
    if typeIndex <> -1 then begin
      SetTypeUsing(AData, typeIndex);
      if AData.Commands[index].Name.InType.StartsWith('struct ') then
        Prepared.extendedTypeNames.AddOrSetValue(typeIndex + Prepared.typesOffset, Copy(AData.Types[typeIndex + Prepared.typesOffset].Name, 8));
    end; }
    SetLength(Prepared.neededCommands[index + Prepared.commandsOffset].Params, Length(AData.Commands[index].Params));
    for m := 0 to High(AData.Commands[index].Params) do begin
      FConverter.RunParse(AData.Commands[index].Params[m].FullText);
      Assert(FConverter.ObjectsCount = 1);
      t:= FConverter.ObjectInfo[0];
      typeIndex:= FixType(t, Prepared.neededCommands[index + Prepared.commandsOffset].Params[m]);

      groupIndex:= -1;
      if AOptions.UseEnumeratesAndSets and (AData.Commands[index].Params[m].Group <> '') and
          not AOptions.IsSetExcluded(AData.Commands[index].Params[m].Group) then begin
        groupIndex:= AData.IndexOfEnumGroup(AData.Commands[index].Params[m].Group);
        if groupIndex <> -1 then begin
          Inc(groupIndex, Prepared.groupsOffset);
          if t.APSpecific <> nil then begin
            Prepared.EnumGroups.AddAP(groupIndex, t.GetAPInfo);
            t.ParentType:= AData.Commands[index].Params[m].Group;
          end else
            t.ParentType:= 'T' + AData.Commands[index].Params[m].Group;
          Prepared.EnumGroups.Using[groupIndex]:= True;
          Prepared.neededCommands[index + Prepared.commandsOffset].Params[m]:= t.ToPascalName('', False);
        end;
      end;

      if groupIndex <> -1 then begin
        UpdateTypeArrays(AData.Commands[index].Params[m].Length, groupIndex, Prepared.EnumGroups);
      end else if typeIndex <> -1 then
        UpdateTypeArrays(AData.Commands[index].Params[m].Length, Prepared.typesOffset + typeIndex, Prepared.TypesInfo);
    end;
  end;

  Prepared.UpdateOffset(AData);
end;

procedure TPascalSaver.InitializePrepared(const AOptions: TGeneratorOptions);
var i, count: Integer;
begin
  Prepared.Finalize(True);

  Prepared.TypesInfo.ExtendedArrays:= TDictionary<Integer, TArray<TArray<TAPData>>>.Create;
  if AOptions.UseEnumeratesAndSets then begin
    Prepared.EnumGroups.ExtendedArrays:= TDictionary<Integer, TArray<TArray<TAPData>>>.Create;
    Prepared.enumIndexes:= TDictionary<Integer, TArray<Integer>>.Create;
    Prepared.skipedEnumIndexes:= TDictionary<Integer, TArray<string>>.Create;
  end;
  Prepared.extendedTypeNames:= TDictionary<Integer, AnsiString>.Create;
  Prepared.PointerLevel:= 0;

  count:= 0;
  for i := 0 to High(LoadedData) do
    Inc(count, Length(LoadedData[i].EnumGroups));
  SetLength(Prepared.EnumGroups.Using, count);
  //SetLength(Prepared.EnumGroups.MaxPointerLevel, count);

  count:= 0;
  for i := 0 to High(LoadedData) do
    Inc(count, Length(LoadedData[i].Enums));
  SetLength(Prepared.neededEnums, count);
  SetLength(Prepared.EnumsInGroup, count);

  count:= 0;
  for i := 0 to High(LoadedData) do
    Inc(count, Length(LoadedData[i].Types));
  SetLength(Prepared.TypesInfo.Using, count);
  //SetLength(Prepared.TypesInfo.MaxPointerLevel, count);

  count:= 0;
  for i := 0 to High(LoadedData) do
    Inc(count, Length(LoadedData[i].Commands));
  SetLength(Prepared.neededCommands, count);
end;

procedure TPascalSaver.InitializeRemove(const AData: TParsedData;
  const AOptions: TGeneratorOptions);
var j, k, l, m: Integer;
    indexes: TArray<Integer>;
    typeIndex, fix, groupIndex, index: Integer;
begin
  for j := 0 to High(AData.Extensions) do
  if AOptions.Selection[Prepared.CurrentData][j] <> cuNone then
  for k:= 0 to High(AData.Extensions[j].Remove) do
  if AData.Extensions[j].Remove[k].Supported = AOptions.Profile then begin
    for l := 0 to High(AData.Extensions[j].Remove[k].Enums) do begin
      index:= AData.IndexOfEnum(AData.Extensions[j].Remove[k].Enums[l]);
      if index <> -1 then
        Prepared.neededEnums[Prepared.enumsOffset + index]:= False;
    end;

    for l:= 0 to High(AData.Extensions[j].Remove[k].Commands) do begin
      index:= AData.IndexOfCommand(AData.Extensions[j].Remove[k].Commands[l]);
      if index <> -1 then
        Prepared.neededCommands[Prepared.commandsOffset + index].CommandUsing:= TCommandUsing.cuNone;
    end;
  end;

  Prepared.UpdateOffset(AData);
end;

procedure TPascalSaver.InitializeRequireCommandsAndConsts(
  const AData: TParsedData; const AOptions: TGeneratorOptions);
var j, k, l, m: Integer;
    indexes: TArray<Integer>;
    typeIndex, fix, groupIndex, index: Integer;
begin
  if AOptions.UseEnumeratesAndSets then begin
    for j := 0 to High(AData.EnumGroups) do begin
      SetLength(indexes, Length(AData.EnumGroups[j].Enums));
      for k := 0 to High(AData.EnumGroups[j].Enums) do
        indexes[k]:= AData.IndexOfEnum(AData.EnumGroups[j].Enums[k]);
      Prepared.enumIndexes.Add(Prepared.groupsOffset + j, indexes);
    end;
    for l := 0 to High(AOptions.CustomForcedSets) do begin
      groupIndex:= AData.IndexOfEnumGroup(AOptions.CustomForcedSets[l]);
      if groupIndex <> -1 then begin
        Inc(groupIndex, Prepared.groupsOffset);
        Prepared.EnumGroups.Using[groupIndex]:= True;
      end;
    end;
  end;

  for j := 0 to High(AData.Extensions) do
  if AOptions.Selection[Prepared.CurrentData][j] <> cuNone then
  for k:= 0 to High(AData.Extensions[j].Require) do
  if (AOptions.Profile = '') or (AData.Extensions[j].Require[k].Supported = '') or
    (AData.Extensions[j].Require[k].Supported = AOptions.Profile) then begin
    for l := 0 to High(AData.Extensions[j].Require[k].Enums) do begin
      index:= AData.IndexOfEnum(AData.Extensions[j].Require[k].Enums[l]);
      if index <> -1 then
        Prepared.neededEnums[Prepared.enumsOffset + index]:= True;
    end;

    for l:= 0 to High(AData.Extensions[j].Require[k].Commands) do begin
      index:= AData.IndexOfCommand(AData.Extensions[j].Require[k].Commands[l]);
      if (index <> -1) and (Integer(Prepared.neededCommands[Prepared.commandsOffset + index].CommandUsing) < Integer(AOptions.Selection[Prepared.CurrentData][j])) then begin
        Prepared.neededCommands[Prepared.commandsOffset + index].CommandUsing:= AOptions.Selection[Prepared.CurrentData][j];
      end;
    end;
  end;

  Prepared.UpdateOffset(AData);
end;

function TPascalSaver.IsCanWithDelphiTypes(const Command: TCommand): Boolean;
var i: Integer;
    l, e: LongWord;
begin
  for i := 0 to High(Command.Params) do begin
    if Command.Params[i].Length = '' then begin
      if GetPointerLevel(Command.Params[i].FullText) = 1 then
        Exit(True);
    end else begin
      val(Command.Params[i].Length, l, e);
      if e = 0 then
        Exit(True);
    end;
  end;
  Result:= False;
end;

function TPascalSaver.IsLegalSetValue(const Value: string): Boolean;
var len, e: LongWord;
begin
  val(StringReplace(Value, '0x', '$', []), len, e);
  Result:= GetNumberOfSetBits32(len) = 1;
end;

function TPascalSaver.IsPointer(const definition: TParam): Boolean;
var i, j: Integer;
begin
  if definition.InType = '' then begin
    if definition.FullText.StartsWith('const ') then
      i:= 7
    else
      i:= 1;
    while definition.FullText[i] = ' ' do
      Inc(i);

    if Length(definition.FullText) - i >= 4 then begin
      for j := 0 to 3 do
        if definition.FullText[j + i] <> 'void'[j + 1] then
          Exit(False);
      Inc(i, 4);

      Result:= (Length(definition.FullText) < i) or
          (definition.FullText[i] = ' ') or
          (definition.FullText[i] = '*');
    end else
      Result:= False;
  end else
    Result:= False;
end;

function TPascalSaver.IsUseDynamicExtensions(
  const AOptions: TGeneratorOptions): Boolean;
var i, j: Integer;
begin
  for i := 0 to High(LoadedData) do
    for j := 0 to High(LoadedData[i].Extensions) do
      if AOptions.Selection[i][j] = cuDynamic then
        Exit(True);
  Result:= False;
end;

procedure TPascalSaver.SaveToStream(const AData: TArray<TParsedData>;
  const AOptions: TGeneratorOptions; AStream: TStream);
var txt, temp, curType, functionStrPos: AnsiString;
    i, j, k, l, m, n, e, count, index, typeIndex, groupIndex: Integer;
    indexes: TArray<TArray<TAPData>>;
    groups: TArray<string>;
    fix, len: Integer;
    need, useDynamic: Boolean;
begin
  FConverter:= TCTypeConverter.Create;
  if AOptions.UnicodePascal then
    functionStrPos:= '  if System.AnsiStrings.StrPos(ExtensionString, '''
  else
    functionStrPos:= '  if StrPos(ExtensionString, ''';
  LoadedData:= AData;
  OutStream:= AStream;
  try
    InitializePrepared(AOptions);

    Prepared.ResetOffset;
    for i := 0 to High(LoadedData) do begin
      Prepared.CurrentData:= i;
      InitializeRequireCommandsAndConsts(LoadedData[i], AOptions);
    end;

    Prepared.ResetOffset;
    for i := 0 to High(LoadedData) do begin
      Prepared.CurrentData:= i;
      InitializeRemove(LoadedData[i], AOptions);
    end;

    Prepared.ResetOffset;
    for i := 0 to High(LoadedData) do begin
      Prepared.CurrentData:= i;
      InitializeCommandsParams(LoadedData[i], AOptions);
    end;

    txt:= 'unit ' + AOptions.UnitName + ';' + sLineBreak + sLineBreak +
        'interface' + sLineBreak + sLineBreak;
    OutStream.Write(Pointer(txt)^, Length(txt));

    if AOptions.AdditionalUses <> '' then begin
      txt:= 'uses ' + AOptions.AdditionalUses + ';' + sLineBreak;
      OutStream.Write(Pointer(txt)^, Length(txt));
    end else begin
      txt:= 'uses System.SysUtils, WinAPI.Windows';
      OutStream.Write(Pointer(txt)^, Length(txt));
      if AOptions.UnicodePascal then
        txt:= ', System.AnsiStrings;' + sLineBreak
      else
        txt:= ';' + sLineBreak;
      OutStream.Write(Pointer(txt)^, Length(txt))
    end;

    txt:= sLineBreak + '{$SCOPEDENUMS ON}' + sLineBreak + '{$Z4}' +
        sLineBreak + sLineBreak;
    OutStream.Write(Pointer(txt)^, Length(txt));

    Prepared.ResetOffset;
    for i := 0 to High(LoadedData) do begin
      txt:= 'type' + sLineBreak;
      OutStream.Write(Pointer(txt)^, Length(txt));
      Prepared.CurrentData:= i;
      for j := 0 to High(LoadedData[i].Types) do
      if Prepared.TypesInfo.Using[Prepared.typesOffset + j] and (LoadedData[i].Types[j].FullText <> '') then begin
        WriteType(LoadedData[i].Types[j]);
        if not Prepared.extendedTypeNames.TryGetValue(Prepared.typesOffset + j, temp) then
          temp:= ConvertDefaultName(LoadedData[i].Types[j].Name);
        if Prepared.TypesInfo.ExtendedArrays.TryGetValue(Prepared.typesOffset + j, indexes) then
          GenerateAPTypeDeclaration(temp, indexes, False);
        txt:= sLineBreak;
        OutStream.Write(Pointer(txt)^, Length(txt));
      end;
      if AOptions.UseEnumeratesAndSets then begin
        for j := 0 to High(LoadedData[i].EnumGroups) do begin
          if not Prepared.EnumGroups.Using[Prepared.groupsOffset + j] then
            Continue;

          WriteEnumOrSet(LoadedData[i], j);

          if Prepared.EnumGroups.ExtendedArrays.TryGetValue(Prepared.groupsOffset + j, indexes) then
            GenerateAPTypeDeclaration(ConvertDefaultName(LoadedData[i].EnumGroups[j].GroupName), indexes, True);
        end;
      end;

      for j := 0 to High(LoadedData[i].Commands) do
      if Prepared.neededCommands[Prepared.commandsOffset + j].CommandUsing = cuDynamic then begin
        need:= IsCanWithDelphiTypes(LoadedData[i].Commands[j]);
        if AOptions.GenerateDefaultCFunctions or not need then begin
          txt:= '  T' + LoadedData[i].Commands[j].Name.Name + 'Proc = ';
          if Prepared.neededCommands[Prepared.commandsOffset + j].ResultType = '' then
            txt:= txt + 'procedure ' + GenerateParamsCStyle(LoadedData[i].Commands[j], Prepared.neededCommands[Prepared.commandsOffset + j]) + '; stdcall;' + sLineBreak
          else
            txt:= txt + 'function ' + GenerateParamsCStyle(LoadedData[i].Commands[j], Prepared.neededCommands[Prepared.commandsOffset + j]) + ': '
                + Prepared.neededCommands[Prepared.commandsOffset + j].ResultType + '; stdcall;' + sLineBreak;
          OutStream.Write(Pointer(txt)^, Length(txt));
        end;
        if AOptions.ConvertPointersToArray and need then begin
          txt:= '  T' + LoadedData[i].Commands[j].Name.Name + 'ProcDelphi = ';
          if Prepared.neededCommands[Prepared.commandsOffset + j].ResultType = '' then
            txt:= txt + 'procedure ' + GenerateParamsWithDelphiTypes(LoadedData[i].Commands[j]) + '; stdcall;' + sLineBreak
          else
            txt:= txt + 'function ' + GenerateParamsWithDelphiTypes(LoadedData[i].Commands[j]) + ': '
                + Prepared.neededCommands[Prepared.commandsOffset + j].ResultType + '; stdcall;' + sLineBreak;
          OutStream.Write(Pointer(txt)^, Length(txt));
        end;
      end;

      need:= False;
      for j := 0 to High(LoadedData[i].Enums) do
      if Prepared.neededEnums[Prepared.enumsOffset + j] and not Prepared.EnumsInGroup[Prepared.enumsOffset + j] then begin
        need:= True;
        Break;
      end;
      if need then begin
        txt:= sLineBreak + 'const' + sLineBreak;
        OutStream.Write(Pointer(txt)^, Length(txt));
        txt:= ';' + sLineBreak;
        for j := 0 to High(LoadedData[i].Enums) do
        if Prepared.neededEnums[Prepared.enumsOffset + j] and not Prepared.EnumsInGroup[Prepared.enumsOffset + j] then begin
          if AOptions.UseEnumeratesAndSets and Prepared.skipedEnumIndexes.TryGetValue(Prepared.enumsOffset + j, groups) then
            WriteSetConst('  ', LoadedData[i].Enums[j].Name, LoadedData[i].Enums[j].Value, groups)
          else begin
            WriteEnumValue('  ', LoadedData[i].Enums[j].Name, LoadedData[i].Enums[j].Value);
            OutStream.Write(Pointer(txt)^, Length(txt));
          end;
        end;
        txt:= sLineBreak;
        OutStream.Write(Pointer(txt)^, Length(txt));
      end;

      Prepared.UpdateOffset(LoadedData[i]);
    end;

    //initialization functions
    useDynamic:= IsUseDynamicExtensions(AOptions);

    if useDynamic then begin
      txt:= sLineBreak + 'type' + sLineBreak + '  TExtensions = (' + sLineBreak;
      OutStream.Write(Pointer(txt)^, Length(txt));

      GenerateDynamicExtensions(AOptions);

      txt:= ');' + sLineBreak + '  TExtensionInitializationEnum = (Functions, ExtensionString);' +
          sLineBreak + '  TExtensionInitialization = set of TExtensionInitializationEnum;' + sLineBreak +
          sLineBreak + 'var' + sLineBreak + '  Extensions: array [TExtensions] of TExtensionInitialization;' + sLineBreak + sLineBreak;
      OutStream.Write(Pointer(txt)^, Length(txt));

      Prepared.ResetOffset;
      for i := 0 to High(LoadedData) do begin
        Prepared.CurrentData:= i;
        for j := 0 to High(LoadedData[i].Commands) do
          if Prepared.neededCommands[Prepared.commandsOffset + j].CommandUsing = cuDynamic then begin
            need:= IsCanWithDelphiTypes(LoadedData[i].Commands[j]);
            if AOptions.GenerateDefaultCFunctions or not need then begin
              txt:= '  ' + LoadedData[i].Commands[j].Name.Name + ': T' + LoadedData[i].Commands[j].Name.Name + 'Proc;' + sLineBreak;
              OutStream.Write(Pointer(txt)^, Length(txt));
            end;
            if AOptions.ConvertPointersToArray and need then begin
              txt:= '  ' + LoadedData[i].Commands[j].Name.Name;
              if AOptions.GenerateDefaultCFunctions then
                txt:= txt + 'Delphi';
              txt:= txt + ': T' + LoadedData[i].Commands[j].Name.Name + 'ProcDelphi;' + sLineBreak;
              OutStream.Write(Pointer(txt)^, Length(txt));
            end;
          end;
        Prepared.UpdateOffset(LoadedData[i]);
      end;

      txt:= sLineBreak;
      OutStream.Write(Pointer(txt)^, Length(txt));

      for i := 0 to High(LoadedData) do
        for j := 0 to High(LoadedData[i].Extensions) do
          if AOptions.Selection[i][j] = cuDynamic then begin
            txt:= 'function Initialize' + LoadedData[i].Extensions[j].Name + '(ExtensionString: PAnsiChar = nil): TExtensionInitialization;' + sLineBreak;
            OutStream.Write(Pointer(txt)^, Length(txt));
          end;

      txt:= 'procedure InitializeAll;' + sLineBreak +
          'function GetInitializationStatistic: string;' + sLineBreak;
      OutStream.Write(Pointer(txt)^, Length(txt));
    end;

    txt:= sLineBreak;
    OutStream.Write(Pointer(txt)^, Length(txt));

    if AOptions.AddGetProcAddress then begin
      txt:= 'function wglGetProcAddress(ProcName: PAnsiChar): Pointer;  stdcall;' + sLineBreak;
      OutStream.Write(Pointer(txt)^, Length(txt));
    end;

    //static functions
    Prepared.ResetOffset;
    for i := 0 to High(LoadedData) do begin
      Prepared.CurrentData:= i;
      for j := 0 to High(LoadedData[i].Commands) do
      if Prepared.neededCommands[Prepared.commandsOffset + j].CommandUsing = cuStatic then begin
        need:= IsCanWithDelphiTypes(LoadedData[i].Commands[j]);
        if AOptions.GenerateDefaultCFunctions or not need then begin
          if Prepared.neededCommands[Prepared.commandsOffset + j].ResultType = '' then
            txt:= 'procedure '
          else
            txt:= 'function ';
          txt:= txt + LoadedData[i].Commands[j].Name.Name + GenerateParamsCStyle(LoadedData[i].Commands[j], Prepared.neededCommands[Prepared.commandsOffset + j]);
          if Prepared.neededCommands[Prepared.commandsOffset + j].ResultType <> '' then
            txt:= txt + ': ' + Prepared.neededCommands[Prepared.commandsOffset + j].ResultType;
          txt:= txt + '; stdcall;' + sLineBreak;
          OutStream.Write(Pointer(txt)^, Length(txt));
        end;
        if AOptions.ConvertPointersToArray and need then begin
          if Prepared.neededCommands[Prepared.commandsOffset + j].ResultType = '' then
            txt:= 'procedure '
          else
            txt:= 'function ';
          txt:= txt + LoadedData[i].Commands[j].Name.Name;
          if AOptions.GenerateDefaultCFunctions then
            txt:= txt + 'Delphi';
          txt:= txt + GenerateParamsWithDelphiTypes(LoadedData[i].Commands[j]);
          if Prepared.neededCommands[Prepared.commandsOffset + j].ResultType <> '' then
            txt:= txt + ': ' + Prepared.neededCommands[Prepared.commandsOffset + j].ResultType;
          txt:= txt + '; stdcall;' + sLineBreak;
          OutStream.Write(Pointer(txt)^, Length(txt));
        end;
      end;
      Prepared.UpdateOffset(LoadedData[i]);
    end;

    txt:= sLineBreak + 'implementation' + sLineBreak + sLineBreak + 'uses TypInfo;' + sLineBreak + sLineBreak;
    OutStream.Write(Pointer(txt)^, Length(txt));

    if AOptions.AddGetProcAddress then begin
      txt:= 'function wglGetProcAddress; external opengl32;' + sLineBreak + sLineBreak;
      OutStream.Write(Pointer(txt)^, Length(txt));
    end;

    //static functions
    Prepared.ResetOffset;
    for i := 0 to High(LoadedData) do begin
      Prepared.CurrentData:= i;
      for j := 0 to High(LoadedData[i].Commands) do
      if Prepared.neededCommands[Prepared.commandsOffset + j].CommandUsing = cuStatic then begin
        need:= IsCanWithDelphiTypes(LoadedData[i].Commands[j]);
        if AOptions.GenerateDefaultCFunctions or not need then begin
          if Prepared.neededCommands[Prepared.commandsOffset + j].ResultType = '' then
            txt:= 'procedure '
          else
            txt:= 'function ';
          txt:= txt + LoadedData[i].Commands[j].Name.Name + '; external opengl32;' + sLineBreak;
          OutStream.Write(Pointer(txt)^, Length(txt));
        end;
        if AOptions.ConvertPointersToArray and need then begin
          if Prepared.neededCommands[Prepared.commandsOffset + j].ResultType = '' then
            txt:= 'procedure '
          else
            txt:= 'function ';
          txt:= txt + LoadedData[i].Commands[j].Name.Name;
          if AOptions.GenerateDefaultCFunctions then
            txt:= txt + 'Delphi';
          txt:= txt + '; external opengl32';
          if AOptions.GenerateDefaultCFunctions then
            txt:= txt + ' name ''' + LoadedData[i].Commands[j].Name.Name + '''';
          txt:= txt + ';' + sLineBreak;
          OutStream.Write(Pointer(txt)^, Length(txt));
        end;
      end;
      Prepared.UpdateOffset(LoadedData[i]);
    end;

    if useDynamic then begin
      txt:= sLineBreak + 'function GetInitializationStatistic: string;' + sLineBreak +
          'var' + sLineBreak +
          '  i: TExtensions;' + sLineBreak +
          '  s, d: string;' + sLineBreak +
          'begin' + sLineBreak +
          '  s:= '''';' + sLineBreak +
          '  for i := Low(TExtensions) to High(TExtensions) do begin' + sLineBreak +
          '    d:= '''';' + sLineBreak +
          '    if TExtensionInitializationEnum.Functions in Extensions[i] then' + sLineBreak +
          '      d:= ''Functions '';' + sLineBreak +
          '    if TExtensionInitializationEnum.ExtensionString in Extensions[i] then' + sLineBreak +
          '      d:= d + ''ExtensionString'';' + sLineBreak +
          '    s:= s + sLineBreak + GetEnumName(TypeInfo(TExtensions), Ord(i)) + '' ['' + d + '']'';' + sLineBreak +
          '  end;' + sLineBreak +
          '  Result:= s;' + sLineBreak +
          'end;' + sLineBreak;
      OutStream.Write(Pointer(txt)^, Length(txt));

      txt:= sLineBreak + 'procedure InitializeAll;' + sLineBreak +
          'var s: PAnsiChar;' + sLineBreak +
          'begin' + sLineBreak +
          '  s:= glGetString(';
      if AOptions.UseEnumeratesAndSets then
        txt:= txt + 'TStringName.';
      txt:= txt + 'GL_EXTENSIONS);' + sLineBreak;
      OutStream.Write(Pointer(txt)^, Length(txt));
      for i := 0 to High(LoadedData) do
        for j := 0 to High(LoadedData[i].Extensions) do
          if AOptions.Selection[i][j] = cuDynamic then begin
            txt:= '  Initialize' + LoadedData[i].Extensions[j].Name + '(s);' + sLineBreak;
            OutStream.Write(Pointer(txt)^, Length(txt));
          end;
      txt:= 'end;' + sLineBreak + sLineBreak;
      OutStream.Write(Pointer(txt)^, Length(txt));

      Prepared.ResetOffset;
      for i := 0 to High(LoadedData) do begin
        Prepared.CurrentData:= i;
        for j := 0 to High(LoadedData[i].Extensions) do if AOptions.Selection[i][j] = cuDynamic then begin
          txt:= 'function Initialize' + LoadedData[i].Extensions[j].Name + '(ExtensionString: PAnsiChar): TExtensionInitialization;' + sLineBreak +
            'begin' + sLineBreak;
          OutStream.Write(Pointer(txt)^, Length(txt));
          for k := 0 to High(LoadedData[i].Extensions[j].Require) do
            for l := 0 to High(LoadedData[i].Extensions[j].Require[k].Commands) do begin
              index:= LoadedData[i].IndexOfCommand(LoadedData[i].Extensions[j].Require[k].Commands[l]);
              if (index <> -1) and (Prepared.neededCommands[Prepared.commandsOffset + index].CommandUsing = cuDynamic) then begin
                txt:= '  ' + LoadedData[i].Extensions[j].Require[k].Commands[l] +
                    ':= wglGetProcAddress(''' + LoadedData[i].Extensions[j].Require[k].Commands[l] +
                    ''');' + sLineBreak;
                if IsCanWithDelphiTypes(LoadedData[i].Commands[index]) and
                    AOptions.ConvertPointersToArray and AOptions.GenerateDefaultCFunctions then begin
                  txt:= txt + '  ' + LoadedData[i].Extensions[j].Require[k].Commands[l] +
                      'Delphi:= wglGetProcAddress(''' + LoadedData[i].Extensions[j].Require[k].Commands[l] +
                      ''');' + sLineBreak;
                end;
                OutStream.Write(Pointer(txt)^, Length(txt));
              end;
            end;
          txt:= '  if ';
          OutStream.Write(Pointer(txt)^, Length(txt));
          need:= False;
          for k := 0 to High(LoadedData[i].Extensions[j].Require) do begin
            for l := 0 to High(LoadedData[i].Extensions[j].Require[k].Commands) do begin
              index:= LoadedData[i].IndexOfCommand(LoadedData[i].Extensions[j].Require[k].Commands[l]);
              if (index <> -1) and (Prepared.neededCommands[Prepared.commandsOffset + index].CommandUsing = cuDynamic) then begin
                txt:= sLineBreak + '      Assigned(' + LoadedData[i].Extensions[j].Require[k].Commands[l] +
                    ') and ';
                OutStream.Write(Pointer(txt)^, Length(txt));
                need:= True;
              end;
            end;
          end;
          if need then
            txt:= 'True then' + sLineBreak + '    Include(Extensions[TExtensions.' +
              LoadedData[i].Extensions[j].Name + '], TExtensionInitializationEnum.Functions);' + sLineBreak
          else
            txt:= 'False then ;' + sLineBreak;
          OutStream.Write(Pointer(txt)^, Length(txt));
          txt:= '  if ExtensionString = nil then' + sLineBreak +
            '    ExtensionString:= glGetString(';
          if AOptions.UseEnumeratesAndSets then
            txt:= txt + 'TStringName.';
          txt:= txt + 'GL_EXTENSIONS);' + sLineBreak +
              functionStrPos + LoadedData[i].Extensions[j].Name + ''') <> nil then' + sLineBreak +
              '    Include(Extensions[TExtensions.' + LoadedData[i].Extensions[j].Name +
              '], TExtensionInitializationEnum.ExtensionString);' + sLineBreak +
              '  Result:= Extensions[TExtensions.' + LoadedData[i].Extensions[j].Name + '];' + sLineBreak +
              'end;' + sLineBreak + sLineBreak;
          OutStream.Write(Pointer(txt)^, Length(txt));
        end;
        Prepared.UpdateOffset(LoadedData[i]);
      end;
    end;

    txt:= 'end.';
    OutStream.Write(Pointer(txt)^, Length(txt));
  finally
    Prepared.Finalize(True);
  end;
end;

procedure TPascalSaver.SetTypeUsing(const AData: TParsedData; Index: Integer);
var nIndex: Integer;
begin
  if not Prepared.TypesInfo.Using[Index + Prepared.typesOffset] then begin
    Prepared.TypesInfo.Using[Index + Prepared.typesOffset]:= True;
    if AData.Types[Index].RequiredType <> '' then begin
      nIndex:= AData.IndexOfType(AData.Types[Index].RequiredType);
      if nIndex >= 0 then
        SetTypeUsing(AData, nIndex);
    end;
  end;
end;

procedure TPascalSaver.UpdateTypeArrays(const strLen: string; index: Integer;
  var collector: TTypeExportInfo);
var len, e, i: Integer;
    indexes: TArray<Integer>;
    ap: TAPData;
begin
  val(strLen, len, e);
  if (e = 0) and (len > 1) then begin
    ap.Create(0, [len]);
    collector.AddAP(index, [ap]);
  end;
end;

procedure TPascalSaver.WriteEnumOrSet(const Data: TParsedData; EnumGroupIndex: Integer);
var txt: AnsiString;
    groupOffset, l, k: Integer;
    indexes: TArray<Integer>;
    groups: TArray<string>;
begin
  groupOffset:= Prepared.groupsOffset + EnumGroupIndex;
  if Data.EnumGroups[EnumGroupIndex].IsSet then begin
    txt:= '  T' + Data.EnumGroups[EnumGroupIndex].GroupName + 'Enum = (' + sLineBreak;
    OutStream.Write(Pointer(txt)^, Length(txt));
    indexes:= Prepared.enumIndexes[groupOffset];
    for k := 0 to High(indexes) do
      if (indexes[k] <> -1) and Prepared.neededEnums[Prepared.enumsOffset + indexes[k]] then begin
        Prepared.EnumsInGroup[Prepared.enumsOffset + indexes[k]]:=
            WriteSetValue(Data.Enums[Prepared.enumsOffset + indexes[k]].Name,
            Data.Enums[Prepared.enumsOffset + indexes[k]].Value);
        if not Prepared.EnumsInGroup[Prepared.enumsOffset + indexes[k]] then begin
          Prepared.skipedEnumIndexes.TryGetValue(Prepared.enumsOffset + indexes[k], groups);
          SetLength(groups, Length(groups) + 1);
          groups[High(groups)]:= Data.EnumGroups[EnumGroupIndex].GroupName;
          Prepared.skipedEnumIndexes.AddOrSetValue(Prepared.enumsOffset + indexes[k], groups);
        end;
      end;
    txt:= '    SET_BEGIN = 0,' + sLineBreak + '    SET_END = 31' + sLineBreak + '    );' + sLineBreak + '  T' + ConvertDefaultName(Data.EnumGroups[EnumGroupIndex].GroupName) +
        ' = set of T' + Data.EnumGroups[EnumGroupIndex].GroupName + 'Enum;' + sLineBreak + sLineBreak;
    OutStream.Write(Pointer(txt)^, Length(txt));
  end else begin
    txt:= '  T' + ConvertDefaultName(Data.EnumGroups[EnumGroupIndex].GroupName) + ' = (' + sLineBreak;
    OutStream.Write(Pointer(txt)^, Length(txt));
    indexes:= Prepared.enumIndexes[groupOffset];
    l:= Length(indexes);
    for k := 0 to High(indexes) do
      if (indexes[k] <> -1) and Prepared.neededEnums[Prepared.enumsOffset + indexes[k]] then begin
        WriteEnumValue('    ', Data.Enums[Prepared.enumsOffset + indexes[k]].Name,
            Data.Enums[Prepared.enumsOffset + indexes[k]].Value);
        Prepared.EnumsInGroup[Prepared.enumsOffset + indexes[k]]:= True;
        l:= k + 1;
        Break;
      end;
    txt:= ',' + sLineBreak;
    for k := l to High(indexes) do
      if (indexes[k] <> -1) and Prepared.neededEnums[Prepared.enumsOffset + indexes[k]] then begin
        OutStream.Write(Pointer(txt)^, Length(txt));
        WriteEnumValue('    ', Data.Enums[Prepared.enumsOffset + indexes[k]].Name,
            Data.Enums[Prepared.enumsOffset + indexes[k]].Value);
        Prepared.EnumsInGroup[Prepared.enumsOffset + indexes[k]]:= True;
      end;
    txt:= sLineBreak + '    );' + sLineBreak + sLineBreak;
    OutStream.Write(Pointer(txt)^, Length(txt));
  end;
end;

procedure TPascalSaver.WriteEnumValue(const Prefix, Name, Value: string);
var txt: AnsiString;
begin
  txt:= Prefix + Name + ' = ' + StringReplace(Value, '0x', '$', []);
  OutStream.Write(Pointer(txt)^, Length(txt));
end;

procedure TPascalSaver.WriteSetConst(const Prefix, Name, Value: string;
  const Groups: TArray<string>);
var txt: AnsiString;
  i: Integer;
begin
  if Length(Groups) > 1 then
    for i := 0 to High(Groups) do begin
      txt:= Prefix + Name + '_' + Groups[i] + ' = T' + Groups[i] + '(' + StringReplace(Value, '0x', '$', []) + ');' + sLineBreak;
      OutStream.Write(Pointer(txt)^, Length(txt));
    end
  else begin
    txt:= Prefix + Name + ' = T' + Groups[0] + '(' + StringReplace(Value, '0x', '$', []) + ');' + sLineBreak;
    OutStream.Write(Pointer(txt)^, Length(txt));
  end
end;

function TPascalSaver.WriteSetValue(const Name, Value: string): Boolean;
var len, e: LongWord;
    txt: AnsiString;
begin
  val(StringReplace(Value, '0x', '$', []), len, e);
  if GetNumberOfSetBits32(len) > 1 then begin
    {$MESSAGE WARN 'Skip this values'}
    Result:= False;
  end else begin
    //OutStream.Write(Pointer(Prefix)^, Length(Prefix));
    txt:= '    ' + Name + ' = ' + IntToStr(GetIndexOfSetBit(len)) + ',' + sLineBreak;
    OutStream.Write(Pointer(txt)^, Length(txt));
    Result:= True;
  end;
end;

procedure TPascalSaver.WriteType(const DataType: TType);
  procedure ParseParam(const str: string; var b: Integer; e: Integer; out param: TParam);
  var l, i, g: Integer;
  begin
    l:= Pos(',', DataType.FullText, b);
    if l = 0 then
      l:= e;
    param.FullText:= Copy(DataType.FullText, b, l - b);
    b:= l + 1;
    if param.FullText = 'void' then
      Exit;
    l:= param.FullText.LastIndexOf(' ');
    i:= param.FullText.LastIndexOf('*');
    if i > l then
      l:= i;
    param.Name:= Copy(param.FullText, l + 2);
    l:= 1;
    if StrLComp(PChar(Pointer(param.FullText)), 'const ', 6) = 0 then begin
      l:= 7;
      while param.FullText[l] = ' ' do Inc(l);
    end;
    i:= Pos(' ', param.FullText, l);
    param.InType:= Copy(param.FullText, l, Pos(' ', param.FullText, l) - l);
    if param.InType = 'void' then
      param.InType:= '';
  end;
var txt, m, a: AnsiString;
    i, k, l: Integer;
    j: ShortInt;
    s: string;
    param: TParam;
    IsSigned: Boolean;
    t: PTypedObject;
label
    anotherTypes;
begin
  if DataType.Name = 'khrplatform' then
    Exit;
  if DataType.Name = 'GLhandleARB' then begin
    txt:= '  ' + DataType.Name + ' = ' + 'THandle';
  end else if DataType.Name = 'GLboolean' then begin
    txt:= '  ' + DataType.Name + ' = ' + 'ByteBool';
  end else if DataType.Name = 'GLsync' then begin
    txt:= '  GLsync = ' + 'record end;' + sLineBreak + '  PGLsync = ^GLsync';
  {end else if DataType.Name = 'struct _cl_context' then begin
    txt:= '  _cl_context = ' + 'record end;' + sLineBreak + '  CLContext = _cl_context' + sLineBreak + '  PCLContext = ^CLContext';
  end else if DataType.Name = 'struct _cl_event' then begin
    txt:= '  _cl_event = ' + 'record end;' + sLineBreak + '  CLEvent = _cl_event' + sLineBreak + '  PCLEvent = ^CLEvent'; }
  end else if (DataType.Name = 'GLchar') or (DataType.Name = 'GLcharARB') then begin
    txt:= '  ' + DataType.Name + ' = AnsiChar'
  end else if DataType.FullText.StartsWith('DECLARE_HANDLE(') then begin
    txt:= '  ' + DataType.Name + ' = THandle';
  end else begin
    if DataType.IsApientry then begin
      txt:= '  ' + ConvertDefaultName(DataType.Name) + ' = ';
      i:= 9;
      while DataType.FullText[i] = ' ' do Inc(i);
      if (StrLComp(@PChar(Pointer(DataType.FullText))[i - 1], 'void', 4) = 0) then begin
        Inc(i, 5);
        while DataType.FullText[i] = ' ' do Inc(i);
        if DataType.FullText[i] <> '(' then
          raise Exception.Create('Wrong output type');
        txt:= txt + 'procedure ';
      end else
        raise Exception.Create('Don''t support');
      i:= Pos('(', DataType.FullText, i + 1) + 1;
      k:= Pos(')', DataType.FullText, i);
      ParseParam(DataType.FullText, i, k, param);
      if param.Name <> '' then begin
        txt:= txt + '(' + GenerateCType(param);
        while i < k do begin
          ParseParam(DataType.FullText, i, k, param);
          txt:= txt + '; ' + GenerateCType(param);
        end;
        txt:= txt + ')';
      end;
      txt:= txt + '; stdcall';
    end else begin
      FConverter.RunParse(DataType.FullText);
      if FConverter.TypesCount <> 0 then begin
        t:= FConverter.TypeInfo[FConverter.TypesCount - 1];
        txt:= '  ' + ConvertDefaultName(t.Name) + ' = ';
        if t.StandardType <> stOtherType then begin
          if t.StandardType = stStruct then begin
            txt:= txt + 'record end';
          end else
            txt:= ConvertDefaultName(t.ToPascalName(txt, True));
        end else begin
          if StrLComp(PChar(Pointer(t.ParentType)), 'khronos_', 8) = 0 then begin
            i:= 9;
            IsSigned:= t.ParentType[i] <> 'u';
            if IsSigned and (StrLComp(@PChar(Pointer(t.ParentType))[i - 1], 'float_t', 7) = 0) then
              txt:= txt + 'Single'
            else begin
              if not IsSigned then
                Inc(i);
              if StrLComp(@PChar(Pointer(t.ParentType))[i - 1], 'int8_t', 6) = 0 then
                txt:= txt + OrdinalTypes[0, IsSigned]
              else if StrLComp(@PChar(Pointer(t.ParentType))[i - 1], 'int16_t', 7) = 0 then
                txt:= txt + OrdinalTypes[1, IsSigned]
              else if StrLComp(@PChar(Pointer(t.ParentType))[i - 1], 'int32_t', 7) = 0 then
                txt:= txt + OrdinalTypes[2, IsSigned]
              else if StrLComp(@PChar(Pointer(t.ParentType))[i - 1], 'int64_t', 7) = 0 then
                txt:= txt + OrdinalTypes[3, IsSigned]
              else if StrLComp(@PChar(Pointer(t.ParentType))[i - 1], 'intptr_t', 8) = 0 then
                txt:= txt + OrdinalTypes[4, IsSigned]
              else if StrLComp(@PChar(Pointer(t.ParentType))[i - 1], 'ssize_t', 7) = 0 then
                txt:= txt + OrdinalTypes[4, True]
              else if StrLComp(@PChar(Pointer(t.ParentType))[i - 1], 'size_t', 6) = 0 then
                txt:= txt + OrdinalTypes[4, IsSigned]
              else
                raise Exception.Create('Unknown delphi type');
            end;
          end else begin
            // int (*x)[5]   is a pointer to an array of five ints.
            // x: ^(array [5] of Integer);
            txt:= ConvertDefaultName(t.ToPascalName(txt, True));
          end;
        end;
      end else
        raise Exception.Create('Unknown delphi type');
    end;
  end;
  txt:= txt + ';' + sLineBreak;
  OutStream.Write(Pointer(txt)^, Length(txt));
end;

function APCompatible(const A, B: array of TAPData): Boolean;
var
  i: Integer;
begin
  if High(A) = High(B) then begin
    for i := 0 to High(A) - 1 do
      if A[i] <> B[i] then
        Exit(False);
    if (Length(A[High(A)].ArraySpecific) = Length(B[High(B)].ArraySpecific)) then begin
      for i := 0 to High(A[High(A)].ArraySpecific) do
        if A[High(A)].ArraySpecific[i] <> B[High(B)].ArraySpecific[i] then
          Exit(False);
      Result:= True;
    end else
      Result:= False;
  end else
    Result:= False;
end;

{ TTypeExportInfo }

procedure TTypeExportInfo.AddAP(Index: Integer; const AP: array of TAPData);
var
  x: TArray<TArray<TAPData>>;

  function Add(const AP: array of TAPData): Boolean;
  var i: Integer;
      v: TArray<TAPData>;
  begin
    for i := 0 to High(x) do
      if APCompatible(x[i], AP) then begin
        if x[i][High(x[i])].PointerCount >= AP[High(AP)].PointerCount then
          Exit(False)
        else begin
          x[i][High(x[i])].PointerCount:= AP[High(AP)].PointerCount;
          Exit(True);
        end;
      end;

    SetLength(v, Length(AP));
    for i := 0 to High(AP) do
      v[i]:= AP[i];

    SetLength(x, Length(x) + 1);
    x[High(x)]:= v;
    Result:= True;
  end;
var
  upd, need: Boolean;
  v: TArray<TAPData>;
  j: Integer;
begin
  upd:= ExtendedArrays.TryGetValue(Index, x);
  need:= False;
  for j := 1 to Length(AP) do
    need:= Add(Slice(AP, j)) or need;

  if need then
    if upd then
      ExtendedArrays[Index]:= x
    else
      ExtendedArrays.Add(Index, x);
end;

procedure TTypeExportInfo.Finalize(UseDefault: Boolean);
begin
  FreeAndNil(ExtendedArrays);
  if UseDefault then
    System.Finalize(Self);
end;

{ TSelectionInfo }

procedure TSelectionInfo.Finalize(UseDefault: Boolean);
begin
  FreeAndNil(enumIndexes);
  FreeAndNil(extendedTypeNames);
  FreeAndNil(skipedEnumIndexes);
  TypesInfo.Finalize(False);
  EnumGroups.Finalize(False);
  if UseDefault then
    System.Finalize(Self);
end;

procedure TSelectionInfo.ResetOffset;
begin
  groupsOffset:= 0;
  typesOffset:= 0;
  commandsOffset:= 0;
  enumsOffset:= 0;
end;

procedure TSelectionInfo.UpdateOffset(const AData: TParsedData);
begin
  Inc(groupsOffset, Length(AData.EnumGroups));
  Inc(enumsOffset, Length(AData.Enums));
  Inc(typesOffset, Length(AData.Types));
  Inc(commandsOffset, Length(AData.Commands));
end;

{ TCTypeConverter }

function TCTypeConverter.AddConvertedType(const AType: TTypedObject): string;
var i: Integer;
begin
  i:= FConvertedTypesList.Add(AType);
  Result:= AType.Name;
  if Result = '' then begin
    Result:= Format('-anonym%d-', [FAnonymousTypesCount]);
    Inc(FAnonymousTypesCount);
  end;
  FTypesDictionary.Add(Result, i);
end;

procedure TCTypeConverter.AddParsed(const AString: string);
var tape: TStringTape;
begin
  tape:= TStringTape.Create(AString);

  FCurrentObject.Clear;
  FCurrentReaderStack.Create(0);

  inherited RunParse(tape, 1);

  if (IsTapeEnd or (GetKey <> ord(';'))) and
      (not FCurrentObject._Object.IsEmpty or not FCurrentObject.TypeDefinition.IsEmpty) then
    EndOfObjectsDeclaration(Self, 0, 0);
end;

class procedure TCTypeConverter.BeginName(Self: TLR1; ACurrentKey: UCS4Char;
  ACurrentState: Integer);
begin

end;

class procedure TCTypeConverter.BeginStructUnion(Self: TLR1;
  ACurrentKey: UCS4Char; ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  if (This.FCurrentObject.APStack.Count > 0) or
      (Length(This.FCurrentObject._Object.APSpecific) > 0) then
    raise Exception.Create('Can''t define struct after pointer');
  This.PushState(Ord('{'));

  This.FCurrentObject.IsDefinedStructOrEnum:= True;
  This.FCurrentReaderStack.Add(This.FCurrentObject);
  This.FCurrentObject.Clear;

  This.ToNextKey;
end;

class procedure TCTypeConverter.CharEnd(Self: TLR1; ACurrentKey: UCS4Char;
  ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  if not This.FCurrentObject.TypeDefinition.SetStandatdType(sctChar) then
    This.CurrentState:= -1;
  This.PopState;//r
  This.PopState;//a
  This.PopState;//h
  This.PopState;//c
end;

procedure TCTypeConverter.ClearObjectsAndTypes;
begin
  FAnonymousTypesCount:= 0;
  FConvertedTypesList.Count:= 0;
  FTypesDictionary.Clear;
  FObjects.Count:= 0;
end;

class procedure TCTypeConverter.ConstTypeEnd(Self: TLR1; ACurrentKey: UCS4Char;
  ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  if This.FCurrentObject.CurrentAP.IsEmpty then begin
    This.FCurrentObject.TypeDefinition.IsConst:= True;
  end else begin
    This.FCurrentObject.CurrentAP.IsConst:= True;
  end;

  This.PopState;//t
  This.PopState;//s
  This.PopState;//n
  This.PopState;//o
  This.PopState;//c
end;

constructor TCTypeConverter.Create;
begin
  inherited Create(@_full, 1);
  FTypeFinished:= TList<TAPInfo>.Create;
  FParsedTypes:= TDictionary<string, TParsedTypedObjectGroup>.Create;
  FConvertedTypesList.Create(5);
  FObjects.Create(5);
  FTypesDictionary:= TDictionary<string, Integer>.Create;
  FObjectsDictionary:= TDictionary<string, Integer>.Create;
  FForwardDefinedStructures:= TStringList.Create;
  FForwardDefinedStructures.Sorted:= True;
  FForwardDefinedStructures.Duplicates:= dupIgnore;
end;

destructor TCTypeConverter.Destroy;
begin
  FTypeFinished.Free;
  FParsedTypes.Free;
  FTypesDictionary.Free;
  FObjectsDictionary.Free;
  FForwardDefinedStructures.Free;
  inherited;
end;

class procedure TCTypeConverter.DoubleEnd(Self: TLR1; ACurrentKey: UCS4Char;
  ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  if not This.FCurrentObject.TypeDefinition.SetStandatdType(sctDouble) then
    This.CurrentState:= -1;
  This.PopState;//e
  This.PopState;//l
  This.PopState;//b
  This.PopState;//u
  This.PopState;//o
  This.PopState;//d
end;

class procedure TCTypeConverter.EndArraySize(Self: TLR1; ACurrentKey: UCS4Char;
  ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  if not This.IsEmptyMagazine and (This.GetState = ord('''')) then //c++14
    This.PopState;
  This.ToNextKey;
end;

class procedure TCTypeConverter.EndOfObjectDeclaration(Self: TLR1;
  ACurrentKey: UCS4Char; ACurrentState: Integer);
var This: TCTypeConverter absolute Self;

  procedure ActualizeType;
  var t: TTypedObject;
  begin
    if (This.FCurrentObject.DefinedType = '') and not This.FCurrentObject.TypeDefinition.IsBuildInType then begin
      if This.FCurrentObject.TypeDefinition.SingleTypeWord = sctStruct then begin
        t.CreateClear(stStruct, This.FCurrentObject.TypeDefinition.TypeName);
        if not This.FCurrentObject.IsDefinedStructOrEnum then begin
          //_Object already contains new variable or type not the defined type
          Assert(This.FCurrentObject.TypeDefinition.TypeName <> '', 'forward declaration must have name');

          {if This.FTypesDictionary.TryGetValue(This.FCurrentObject.TypeDefinition.TypeName, This.FCurrentObject.TypeIndex) then begin
            if This.FForwardDefinedStructures.IndexOf(This.FCurrentObject.TypeDefinition.TypeName) >= 0 then begin
              Assert(Length(This.FCurrentObject._Object.APSpecific) >= 1, 'forward declaration can be only pointer');
              Assert(This.FCurrentObject._Object.APSpecific[0].PointerCount >= 1, 'forward declaration can be only pointer');
            end;

            Exit;
          end;}
          This.FCurrentObject.DefinedType:= This.FCurrentObject.TypeDefinition.TypeName;
          if not This.FCurrentObject._Object.IsEmpty then begin
            Assert(Length(This.FCurrentObject._Object.APSpecific) >= 1, 'forward declaration can be only pointer');
            Assert(This.FCurrentObject._Object.APSpecific[0].PointerCount >= 1, 'forward declaration can be only pointer');
          end;

          This.FForwardDefinedStructures.Add(t.Name);
        end;

        t.FieldsOrArgument:= This.FCurrentObject._Object.FieldsOrArgument;
        t.IsConst:= False;
        This.FCurrentObject.DefinedType:= This.AddConvertedType(t);
      end else
        This.FCurrentObject.DefinedType:= This.FCurrentObject.TypeDefinition.TypeName;
    end;
  end;

var i, ofs: Integer;
    t: TTypedObject;
begin
  This.FCurrentObject.FixCurrentAP;

  with This.FCurrentObject do begin
    ofs:= Length(_Object.APSpecific);
    SetLength(_Object.APSpecific, Length(_Object.APSpecific) + APStack.Count);
    for i := APStack.Count - 1 downto 0 do begin
      _Object.APSpecific[ofs]:= APStack[i];
      Inc(ofs);
    end;
    APStack.Count:= 0;
  end;

  {$IFDEF UnitTests}
  This.DefinedObject:= This.FCurrentObject;
  {$ENDIF}

  if This.IsMagazineEqual(Ord('(')) then begin
    //function argument parsed
  end else if This.IsMagazineEqual(Ord('{')) then begin
    //struct or enum
    if This.FCurrentReaderStack.Count = 0 then
      raise Exception.Create('Error Message');

    ActualizeType;

    if This.FCurrentObject.DefinedType = '' then begin
      This.FCurrentObject._Object.FillBuildInType(This.FCurrentObject.TypeDefinition);
    end else begin
      This.FCurrentObject._Object.StandardType:= stOtherType;
      This.FCurrentObject._Object.ParentType:= This.FCurrentObject.DefinedType;
    end;

    with This.FCurrentReaderStack.List[This.FCurrentReaderStack.Count - 1]._Object do begin
      SetLength(FieldsOrArgument, Length(FieldsOrArgument) + 1);
      FieldsOrArgument[High(FieldsOrArgument)]:= This.FCurrentObject._Object;
    end;
  end else begin
    //type declaration
    ActualizeType;

    if This.FCurrentObject.DefinedType = '' then begin
      This.FCurrentObject._Object.FillBuildInType(This.FCurrentObject.TypeDefinition);
    end else begin
      This.FCurrentObject._Object.StandardType:= stOtherType;
      This.FCurrentObject._Object.ParentType:= This.FCurrentObject.DefinedType;
    end;

    if This.FCurrentObject.TypeDefinition.IsTypeDef then begin
      This.FCurrentObject._Object.IsConst:= False;
      This.AddConvertedType(This.FCurrentObject._Object);
    end else begin
      if This.FCurrentObject.TypeDefinition.SingleTypeWord <> sctStruct then
        Assert(This.FCurrentObject._Object.Name <> '', 'variable must have name');

      if not This.FCurrentObject._Object.IsEmpty then begin
        This.FCurrentObject._Object.IsConst:= This.FCurrentObject.TypeDefinition.IsConst;
        This.FObjects.Add(This.FCurrentObject._Object);
      end;
    end;
  end;

  This.FCurrentObject._Object.Clear;

  if ACurrentKey = Ord(',') then
    This.ToNextKey;
end;

class procedure TCTypeConverter.EndOfObjectsDeclaration(Self: TLR1;
  ACurrentKey: UCS4Char; ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
    i: Integer;
    t: TTypedObject;
begin
  if (not This.IsEmptyMagazine) and (This.GetState <> Ord('{')) then
    raise Exception.Create('Magazine: ' + This.GetMagazineAsString());

  EndOfObjectDeclaration(Self, 0, ACurrentState);

  if ACurrentKey = Ord(';') then
    This.ToNextKey;

  This.FCurrentObject.Clear;
end;

class procedure TCTypeConverter.EndStructUnion(Self: TLR1;
  ACurrentKey: UCS4Char; ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  //if ; missed before }
  if not This.FCurrentObject._Object.IsEmpty then
    EndOfObjectDeclaration(Self, 0, ACurrentState);

  if This.PopState <> Ord('{') then
    raise Exception.Create('Error Message');

  This.FCurrentObject:= This.FCurrentReaderStack.Last;

  This.ToNextKey;
end;

class procedure TCTypeConverter.FloatEnd(Self: TLR1; ACurrentKey: UCS4Char;
  ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  if not This.FCurrentObject.TypeDefinition.SetStandatdType(sctFloat) then
    This.CurrentState:= -1;
  This.PopState;//t
  This.PopState;//a
  This.PopState;//o
  This.PopState;//l
  This.PopState;//f
end;

function TCTypeConverter.GetObjectInfo(Index: Integer): TTypedObject;
begin
  Result:= FObjects[Index];
end;

function TCTypeConverter.GetObjectsCount: Integer;
begin
  Result:= FObjects.Count;
end;

function TCTypeConverter.GetTypeInfo(Index: Integer): PTypedObject;
begin
  Result:= @FConvertedTypesList.List[Index];
end;

function TCTypeConverter.GetTypeInfoByName(Index: string): PTypedObject;
var i: Integer;
begin
  if FTypesDictionary.TryGetValue(Index, i) then
    Result:= @FConvertedTypesList.List[i]
  else
    Result:= nil;
end;

function TCTypeConverter.GetTypesCount: Integer;
begin
  Result:= FConvertedTypesList.Count;
end;

class procedure TCTypeConverter.GoDeepType(Self: TLR1; ACurrentKey: UCS4Char;
  ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  //if not This.FCurrent.IsEmpty then begin
    This.FCurrentObject.APStack.Add(This.FCurrentObject.CurrentAP);
    This.FCurrentObject.CurrentAP.Clear;
  //end;

  This.PushState(ACurrentKey);
  This.ToNextKey;
end;

class procedure TCTypeConverter.GoFunctionReader(Self: TLR1;
  ACurrentKey: UCS4Char; ACurrentState: Integer);
begin
  raise Exception.Create('Error Message');
end;

class procedure TCTypeConverter.GoUpType(Self: TLR1; ACurrentKey: UCS4Char;
  ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
    i: Integer;
begin
  if This.PopState <> ord('(') then
    raise Exception.Create('Error Message');

  This.FCurrentObject.FixCurrentAP;

  if This.FCurrentObject.APStack.Count > 0 then begin
    This.FCurrentObject.CurrentAP:= This.FCurrentObject.APStack.Last;
    This.FCurrentObject.APStack.Delete(This.FCurrentObject.APStack.Count - 1);
    This.CurrentState:= _state_readThirdTypePart;
  end;
  This.ToNextKey;
end;

class procedure TCTypeConverter.GrowPointerLevel(Self: TLR1;
  ACurrentKey: UCS4Char; ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  if This.FCurrentObject.CurrentAP.IsConst then begin
    This.FCurrentObject.APStack.Add(This.FCurrentObject.CurrentAP);
    This.FCurrentObject.CurrentAP.Clear;
  end;
  Inc(This.FCurrentObject.CurrentAP.PointerCount);
  {with This.DefinedObjects[High(This.DefinedObjects)] do begin
    CheckAPSpecificLength(1);
    Inc(APSpecific[High(APSpecific)].PointerCount);
  end;}
  This.ToNextKey;
end;

class procedure TCTypeConverter.IntEnd(Self: TLR1; ACurrentKey: UCS4Char;
  ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  if not This.FCurrentObject.TypeDefinition.SetStandatdType(sctInt) then
    This.CurrentState:= -1;
  This.PopState;//t
  This.PopState;//n
  This.PopState;//i
end;

class procedure TCTypeConverter.LongEnd(Self: TLR1; ACurrentKey: UCS4Char;
  ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  if This.FCurrentObject.TypeDefinition.Long < 0 then
    This.CurrentState:= -1;
  Inc(This.FCurrentObject.TypeDefinition.Long);
  This.PopState;//g
  This.PopState;//n
  This.PopState;//o
  This.PopState;//l
end;

class procedure TCTypeConverter.NewArraySize(Self: TLR1; ACurrentKey: UCS4Char;
  ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  This.FNumeralSystem:= 8;
  SetLength(This.FCurrentObject.CurrentAP.ArraySpecific, Length(This.FCurrentObject.CurrentAP.ArraySpecific) + 1);
  This.FCurrentObject.CurrentAP.ArraySpecific[High(This.FCurrentObject.CurrentAP.ArraySpecific)].RealValue:= 0;
  This.ToNextKey;
end;

class procedure TCTypeConverter.ReadCustomTypeName(Self: TLR1;
  ACurrentKey: UCS4Char; ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  if not This.FCurrentObject.TypeDefinition.DefinedAsBuildInType then begin
    This.FCurrentObject.TypeDefinition.TypeName:= This.PopMagazineAsString(This.GetLastMagazine([Ord('('), Ord('{')]) + 1);
    {if not This.FTypesDictionary.ContainsKey(This.FCurrentObject.TypeDefinition.TypeName)
        and (This.FCurrentObject.TypeDefinition.SingleTypeWord <> sctStruct) then begin

      This.FCurrentObject._Object.Name:= This.FCurrentObject.TypeDefinition.TypeName;
      This.FCurrentObject.TypeDefinition.TypeName:= '';
      This.CurrentState:= _state_readThirdTypePart;
    end;}
  end else
    UniversalEndName(Self, ACurrentKey, ACurrentState);
end;

procedure TCTypeConverter.RunParse(const AString: string);
begin
  ClearObjectsAndTypes;
  AddParsed(AString);
end;

class procedure TCTypeConverter.SelectArrayBinNumeralSystem(Self: TLR1;
  ACurrentKey: UCS4Char; ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  This.FNumeralSystem:= 2;
  if This.PopState <> ord('0') then
    raise Exception.Create('Error Message');
  This.ToNextKey;
end;

class procedure TCTypeConverter.SelectArrayDecNumeralSystem(Self: TLR1;
  ACurrentKey: UCS4Char; ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  This.FNumeralSystem:= 10;
end;

class procedure TCTypeConverter.SelectArrayHexNumeralSystem(Self: TLR1;
  ACurrentKey: UCS4Char; ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  This.FNumeralSystem:= 16;
  if This.PopState <> ord('0') then
    raise Exception.Create('Error Message');
  This.ToNextKey;
end;

class procedure TCTypeConverter.SelectArrayOctalNumeralSystem(Self: TLR1;
  ACurrentKey: UCS4Char; ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  This.FNumeralSystem:= 8;
  if This.PopState <> ord('0') then
    raise Exception.Create('Error Message');
end;

class procedure TCTypeConverter.SelectCustomTypeOrName(Self: TLR1;
  ACurrentKey: UCS4Char; ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  if This.FCurrentObject.TypeDefinition.DefinedAsBuildInType then
    This.CurrentState:= This._state_readSecondTypePart
  else
    This.CurrentState:= This._state_readCustomType;
end;

class procedure TCTypeConverter.ShortEnd(Self: TLR1; ACurrentKey: UCS4Char;
  ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  if This.FCurrentObject.TypeDefinition.Long <> 0 then
    This.CurrentState:= -1;
  This.FCurrentObject.TypeDefinition.Long:= -1;
  This.PopState;//t
  This.PopState;//r
  This.PopState;//o
  This.PopState;//h
  This.PopState;//s
end;

class procedure TCTypeConverter.SignedEnd(Self: TLR1;
  ACurrentKey: UCS4Char; ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  if This.FCurrentObject.TypeDefinition.Sign <> 0 then
    This.CurrentState:= -1;
  This.FCurrentObject.TypeDefinition.Sign:= -1;
  This.PopState;//d
  This.PopState;//e
  This.PopState;//n
  This.PopState;//g
  This.PopState;//i
  This.PopState;//s
end;

class procedure TCTypeConverter.StructEnd(Self: TLR1; ACurrentKey: UCS4Char;
  ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  if (This.FCurrentObject.TypeDefinition.DefinedAsBuildInType) or
      (This.FCurrentObject.TypeDefinition.TypeName <> '') then
    This.CurrentState:= -1;
  This.FCurrentObject.TypeDefinition.SingleTypeWord:= sctStruct;
  This.PopState;//t
  This.PopState;//c
  This.PopState;//u
  This.PopState;//r
  This.PopState;//t
  This.PopState;//s

  This.PushState($20000 + _state_readCustomType);
  //This.PushState($20000 + _state_readThirdTypePart);
end;

class procedure TCTypeConverter.TypedefEnd(Self: TLR1; ACurrentKey: UCS4Char;
  ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  if This.FCurrentObject.TypeDefinition.TypeName <> '' then
    This.CurrentState:= -1;
  This.FCurrentObject.TypeDefinition.IsTypeDef:= True;
  This.PopState;//f
  This.PopState;//e
  This.PopState;//d
  This.PopState;//e
  This.PopState;//p
  This.PopState;//y
  This.PopState;//t
end;

class procedure TCTypeConverter.UniversalEndName(Self: TLR1;
  ACurrentKey: UCS4Char; ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  This.FCurrentObject._Object.Name:=
      This.PopMagazineAsString(This.GetLastMagazine([Ord('('), Ord('{')]) + 1);
  This.CurrentState:= _state_readThirdTypePart;
end;

class procedure TCTypeConverter.UnsignedEnd(Self: TLR1; ACurrentKey: UCS4Char;
  ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  if This.FCurrentObject.TypeDefinition.Sign <> 0 then
    This.CurrentState:= -1;
  This.FCurrentObject.TypeDefinition.Sign:= 1;
  This.PopState;//d
  This.PopState;//e
  This.PopState;//n
  This.PopState;//g
  This.PopState;//i
  This.PopState;//s
  This.PopState;//n
  This.PopState;//u
end;

class procedure TCTypeConverter.UpdateHexNumberArraySize(Self: TLR1;
  ACurrentKey: UCS4Char; ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  This.FCurrentObject.CurrentAP.UpgradeLastArraySize(This.FNumeralSystem, ACurrentKey or $20 - ord('a') + 10);
  if not This.IsEmptyMagazine and (This.GetState = ord('''')) then
    This.PopState;
  This.ToNextKey;
end;

class procedure TCTypeConverter.UpdateNumberArraySize(Self: TLR1;
  ACurrentKey: UCS4Char; ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  This.FCurrentObject.CurrentAP.UpgradeLastArraySize(This.FNumeralSystem, ACurrentKey - ord('0'));
  if not This.IsEmptyMagazine and (This.GetState = ord('''')) then
    This.PopState;
  This.ToNextKey;
end;

class procedure TCTypeConverter.VoidEnd(Self: TLR1; ACurrentKey: UCS4Char;
  ACurrentState: Integer);
var This: TCTypeConverter absolute Self;
begin
  if not This.FCurrentObject.TypeDefinition.SetStandatdType(sctVoid) then
    This.CurrentState:= -1;
  This.PopState;//d
  This.PopState;//i
  This.PopState;//o
  This.PopState;//v
end;

{ TParsedTypedObject }

procedure TParsedTypedObject.CheckAPSpecificLength(ALength: Integer);
var i, count: Integer;
begin
  count:= Length(APSpecific);
  if count < ALength then begin
    SetLength(APSpecific, ALength);
    for i := count to ALength - 1 do
      APSpecific[i].PointerCount:= 0;
  end
end;

procedure TParsedTypedObject.Clear;
begin
  Name:= '';
  FunctionData:= nil;
  APSpecific:= nil;
end;

{ TTypeDefinition }

procedure TTypeDefinition.Clear;
begin
  Sign:= 0;
  IsTypeDef:= False;
  Long:= 0;
  SingleTypeWord:= sctDefault;
  TypeName:= '';
  IsConst:= False;
end;

function TTypeDefinition.DefinedAsBuildInType: Boolean;
begin
  Result:= (TypeName = '') and (
      ((SingleTypeWord <> sctStruct) and (SingleTypeWord <> sctStruct) and (SingleTypeWord <> sctDefault))
      or (Sign <> 0) or (Long <> 0));
end;

function TTypeDefinition.IsBuildInType: Boolean;
begin
  Result:= (TypeName = '') and (((SingleTypeWord <> sctStruct) and (SingleTypeWord <> sctStruct)) or (Sign <> 0) or (Long <> 0));
end;

function TTypeDefinition.IsEmpty: Boolean;
begin
  Result:= (Sign = 0) and not IsTypeDef and (Long = 0) and (SingleTypeWord = sctDefault) and (TypeName = '') and not IsConst;
end;

function TTypeDefinition.SetLongValue(AValue: Integer): Boolean;
begin

end;

function TTypeDefinition.SetStandatdType(AType: TStandardCType): Boolean;
begin
  if SingleTypeWord = sctDefault then begin
    Result:= True;
    case AType of
      sctChar: Result:= (Long = 0) and (TypeName = '');
      sctInt: Result:= TypeName = '';
      sctVoid: Result:= (Long = 0) and (Sign = 0) and (TypeName = '');
      sctFloat,sctDouble: Result:= (Long < 2) and (Long >= 0) and (Sign = 0);
      //sctBool
    end;
    if Result then
      SingleTypeWord:= AType;
  end else
    Result:= False;
end;

function TTypeDefinition.ToPascalName: string;
begin
  if IsBuildInType then begin
    case SingleTypeWord of
      sctChar: Result:= OrdinalTypes[0, Sign <> 1];
      sctInt, sctDefault:
        case Long of
          -1: Result:= OrdinalTypes[1, Sign <> 1];
          0: Result:= OrdinalTypes[2, Sign <> 1];
          1: Result:= OrdinalTypes[3, Sign <> 1];
        end;
      sctFloat:
        if Long = 0 then
          Result:= 'Single'
        else
          Result:= 'Double';
      sctDouble:
        if Long = 0 then
          Result:= 'Double'
        else
          Result:= 'Extended';// в последних версиях 10байтный флоат отсутствует и равен Double
    end;
  end else
    Result:= TypeName;
end;

{ TAPInfo }

procedure TAPInfo.Clear;
begin
  ArraySpecific:= nil;
  PointerCount:= 0;
  IsConst:= False;
end;

constructor TAPInfo.Create(APointerCount: Integer; AIsConst: Boolean;
  const ASpec: array of TParsedIntConst);
var
  i: Integer;
begin
  PointerCount:= APointerCount;
  IsConst:= AIsConst;
  SetLength(ArraySpecific, Length(ASpec));
  for i := 0 to High(ASpec) do
    ArraySpecific[i]:= ASpec[i];
end;

class operator TAPInfo.Equal(const A, B: TAPInfo): Boolean;
var i: Integer;
begin
  if (A.PointerCount = B.PointerCount) and (A.IsConst = B.IsConst) and
      (Length(A.ArraySpecific) = Length(B.ArraySpecific)) then begin
    for i := 0 to High(A.ArraySpecific) do
      if A.ArraySpecific[i].RealValue <> B.ArraySpecific[i].RealValue then
        Exit(False);
    Result:= True;
  end else
    Result:= False;
end;

class operator TAPInfo.Implicit(const V: TAPInfo): TAPData;
var
  i: Integer;
begin
  Result.PointerCount:= V.PointerCount;
  SetLength(Result.ArraySpecific, Length(V.ArraySpecific));
  for i := 0 to High(V.ArraySpecific) do
    Result.ArraySpecific[i]:= V.ArraySpecific[i].RealValue;
end;

function TAPInfo.IsEmpty: Boolean;
begin
  Result:= (PointerCount = 0) and (ArraySpecific = nil) and not IsConst;
end;

class operator TAPInfo.NotEqual(const A, B: TAPInfo): Boolean;
begin
  Result:= not (A = B);
end;

procedure TAPInfo.UpgradeLastArraySize(NumeralSystem, Value: Integer);
begin
  ArraySpecific[High(ArraySpecific)].RealValue:= ArraySpecific[High(ArraySpecific)].RealValue *
    NumeralSystem + Value;
end;

{ TTypedObject }

procedure TTypedObject.Clear;
begin
  Name:= '';
  FieldsOrArgument:= nil;
  APSpecific:= nil;
  IsConst:= False;
  BitLength:= 0;
  ParentType:= '';
end;

constructor TTypedObject.Create(const Parsed: TTypeDefinition; Converter: TCTypeConverter);
begin
  if Parsed.IsBuildInType then begin
    case Parsed.SingleTypeWord of
      sctDefault, sctChar, sctInt, sctBool:
        begin
          if Parsed.Sign = 1 then
            StandardType:= stUInt
          else
            StandardType:= stInt;
        end;
      sctVoid: StandardType:= stVoid;
      sctFloat, sctDouble: StandardType:= stFloat;
    end;
    case Parsed.SingleTypeWord of
      sctChar: BitLength:= 8;
      sctInt, sctDefault:
        case Parsed.Long of
          -1: BitLength:= 16;
          0: BitLength:= 32;
          1: BitLength:= 64;
        end;
      sctFloat:
        if Parsed.Long = 0 then
          BitLength:= 32
        else
          BitLength:= 64;
      sctDouble:
        if Parsed.Long = 0 then
          BitLength:= 64
        else
          BitLength:= 80;// в последних версиях 10байтный флоат отсутствует и равен Double
    end;
  end else begin
    if Parsed.SingleTypeWord = sctStruct then begin
      StandardType:= stStruct;
    end else begin
      StandardType:= stOtherType;
    end;
  end;
  IsConst:= Parsed.IsConst;
  //FieldsOrArgument:= nil;
  //APSpecific:= nil;
end;

constructor TTypedObject.CreateClear(AStandardType: TStandardType;
  const AName: string);
begin
  Name:= AName;
  StandardType:= AStandardType;
  BitLength:= 0;
  FieldsOrArgument:= nil;
  APSpecific:= nil;
end;

constructor TTypedObject.CreateFull(const AName: string;
  AStandardType: TStandardType; ABitLength: Integer);
begin
  Name:= AName;
  StandardType:= AStandardType;
  BitLength:= ABitLength;
  APSpecific:= nil;
  FieldsOrArgument:= nil;
end;

constructor TTypedObject.CreateFull(const AName: string; const AParentType: string;
  AStandardType: TStandardType; const APSpec: array of TAPInfo;
  const AFOA: array of TTypedObject);
var
  i: Integer;
begin
  Name:= AName;
  ParentType:= AParentType;
  StandardType:= AStandardType;
  SetLength(APSpecific, Length(APSpec));
  for i := 0 to High(APSpec) do
    APSpecific[i]:= APSpec[i];
  SetLength(FieldsOrArgument, Length(AFOA));
  for i := 0 to High(AFOA) do
    FieldsOrArgument[i]:= AFOA[i];
end;

class operator TTypedObject.Equal(const A, B: TTypedObject): Boolean;
var i: Integer;
begin
  if (A.StandardType = B.StandardType) and (A.Name = B.Name) then
    case A.StandardType of
      stInt, stUInt, stVoid, stFloat:
        begin
          Result:= A.BitLength = B.BitLength;
        end;
      stStruct, stOtherType:
        if (A.ParentType = B.ParentType) and
            (Length(A.APSpecific) = Length(B.APSpecific)) then begin
          for i := 0 to High(A.APSpecific) do
            if A.APSpecific[i] <> B.APSpecific[i] then
              Exit(False);
          if (Length(A.FieldsOrArgument) = Length(B.FieldsOrArgument)) then begin
            for i := 0 to High(A.FieldsOrArgument) do
              if A.FieldsOrArgument[i] <> B.FieldsOrArgument[i] then
                Exit(False);
            Result:= True;
          end else
            Result:= False;
        end else
          Result:= False;
    else
      Result:= False;
    end
  else
    Result:= False;
end;

procedure TTypedObject.FillAP(const AP: array of TAPInfo);
var
  i: Integer;
begin
  SetLength(APSpecific, Length(AP));
  for i := 0 to High(AP) do
    APSpecific[i]:= AP[i];
end;

procedure TTypedObject.FillBuildInType(const Parsed: TTypeDefinition);
begin
  if Parsed.IsBuildInType then begin
    case Parsed.SingleTypeWord of
      sctDefault, sctChar, sctInt, sctBool:
        begin
          if Parsed.Sign = 1 then
            StandardType:= stUInt
          else
            StandardType:= stInt;
        end;
      sctVoid: StandardType:= stVoid;
      sctFloat, sctDouble: StandardType:= stFloat;
    end;
    case Parsed.SingleTypeWord of
      sctChar: BitLength:= 8;
      sctInt, sctDefault:
        case Parsed.Long of
          -1: BitLength:= 16;
          0: BitLength:= 32;
          1: BitLength:= 64;
        end;
      sctFloat:
        if Parsed.Long = 0 then
          BitLength:= 32
        else
          BitLength:= 64;
      sctDouble:
        if Parsed.Long = 0 then
          BitLength:= 64
        else
          BitLength:= 80;// в последних версиях 10байтный флоат отсутствует и равен Double
    end;
  end;
end;

function TTypedObject.GetAPInfo: TArray<TAPData>;
var c: Integer;
  i, p: Integer;
begin
  c:= 1;
  for i := 0 to High(APSpecific) do
    if APSpecific[i].ArraySpecific <> nil then
      Inc(c);

  Result:= nil;
  SetLength(Result, c);
  if APSpecific[High(APSpecific)].ArraySpecific = nil then
    Dec(c);
  for i := 0 to High(APSpecific) do begin
    if APSpecific[i].ArraySpecific <> nil then begin
      p:= Result[c].PointerCount;
      Result[c]:= APSpecific[i];
      Result[c].PointerCount:= p;
      Dec(c);
    end;
    Inc(Result[c].PointerCount, APSpecific[i].PointerCount);
  end;
end;

function TTypedObject.IsEmpty: Boolean;
begin
  Result:= Name = '';
end;

class operator TTypedObject.NotEqual(const A, B: TTypedObject): Boolean;
begin
  Result:= not (A = B);
end;

function TTypedObject.ToPascalName(ADefinition: string; AddNewTypes: Boolean): string;
var s, m, a: string;
    k, l: Integer;
begin
  case StandardType of
    stInt, stUInt: case BitLength of
         8: Result:= OrdinalTypes[0, StandardType <> stUInt];
        16: Result:= OrdinalTypes[1, StandardType <> stUInt];
        32: Result:= OrdinalTypes[2, StandardType <> stUInt];
        64: Result:= OrdinalTypes[3, StandardType <> stUInt];
      end;
    stVoid: Result:= 'ointer';
    stFloat: case BitLength of
        32: Result:= 'Single';
        64: Result:= 'Double';
        80: Result:= 'Extended';
      end;
    stStruct: ;
    stOtherType: Result:= ParentType;
  else
    Result:= '';
  end;

  if Length(APSpecific) > 0 then begin
    s:= ConvertDefaultName(Result);
    if s = 'THandle' then
      s:= 'Handle';
    m:= '';
    for k := High(APSpecific) - 1 downto 0 do begin
      for l := 1 to APSpecific[k].PointerCount do begin
        if AddNewTypes then
          m:= m + '  P' + s + ' = ^' + s + ';' + sLineBreak;
        s:= 'P' + s;
      end;
      if AddNewTypes then begin
        a:= '';
        for l:= 0 to High(APSpecific[k].ArraySpecific) do
          a:= a + 'array [0..' + IntToStr(APSpecific[k].ArraySpecific[l].RealValue - 1) + '] of ';
        if a <> '' then begin
          a:= a + s;
          for l:= 0 to High(APSpecific[k].ArraySpecific) do
            s:= s + intToStr(APSpecific[k].ArraySpecific[l].RealValue) + 'v';
          m:= m + '  ' + s + ' = ' + a + ';' + sLineBreak;
        end;
      end else
        for l:= 0 to High(APSpecific[k].ArraySpecific) do
          s:= s + intToStr(APSpecific[k].ArraySpecific[l].RealValue) + 'v';
    end;

    if Length(APSpecific[0].ArraySpecific) = 0 then begin
      l:= 1;
      if (StandardType = stVoid) or AddNewTypes then
        l:= 2;
      for l := l to APSpecific[0].PointerCount do begin
        if AddNewTypes then
          m:= m + '  P' + s + ' = ^' + s + ';' + sLineBreak;
        s:= 'P' + s;
      end;
      if StandardType = stVoid then
        s:= 'P' + s
      else if AddNewTypes then
        s:= '^' + s;
      Result:= m + ADefinition + s;
    end else begin
      for l := 1 to APSpecific[0].PointerCount do begin
        if AddNewTypes then
          m:= m + '  P' + s + ' = ^' + s + ';' + sLineBreak;
        s:= 'P' + s;
      end;
      a:= '';
      if AddNewTypes then
        for l:= 0 to High(APSpecific[0].ArraySpecific) do
          a:= a + 'array [0..' + IntToStr(APSpecific[0].ArraySpecific[l].RealValue - 1) + '] of ';
      Result:= m + ADefinition + a + s;
    end;
  end else
    Result:= ADefinition + ConvertDefaultName(Result);
end;

{ TParsedTypedObjectGroup }

procedure TParsedTypedObjectGroup.Clear;
begin
  TypeDefinition.Clear;
  DefinedType:= '';
  APStack.Create(0);
  CurrentAP.Clear;
  _Object.Clear;
  IsDefinedStructOrEnum:= False;
end;

procedure TParsedTypedObjectGroup.FixCurrentAP;
begin
  if not CurrentAP.IsEmpty then begin
    SetLength(_Object.APSpecific, Length(_Object.APSpecific) + 1);
    _Object.APSpecific[High(_Object.APSpecific)]:= CurrentAP;
    CurrentAP.Clear;
  end;
end;

{ TParsedIntConst }

class operator TParsedIntConst.Implicit(Value: Integer): TParsedIntConst;
begin
  Result.RealValue:= Value;
end;

{ TAPData }

constructor TAPData.Create(APointerCount: Integer;
  const ASpec: array of Integer);
begin
  PointerCount:= APointerCount;
  SetLength(ArraySpecific, Length(ASpec));
  Move(ASpec[0], ArraySpecific[0], Length(ASpec) * SizeOf(integer));
end;

class operator TAPData.Equal(const A, B: TAPData): Boolean;
var
  i: Integer;
begin
  if (A.PointerCount = B.PointerCount) and (Length(A.ArraySpecific) = Length(B.ArraySpecific)) then begin
    for i := 0 to High(A.ArraySpecific) do
      if A.ArraySpecific[i] <> B.ArraySpecific[i] then
        Exit(False);
    Result:= True;
  end else
    Result:= False;
end;

function TAPData.GenerateName(N: AnsiString): AnsiString;
begin
  Result:= GetNamePrefix + N + GetNameSuffix;
end;

function TAPData.GetArrayTypeDef: AnsiString;
var
  i: Integer;
begin
  Result:= '';
  if ArraySpecific <> nil then begin
    Result:= 'array [0..' + IntToStr(ArraySpecific[0] - 1);
    for i := 1 to High(ArraySpecific) do
      Result:= Result + ', 0..' + IntToStr(ArraySpecific[i] - 1);
    Result:= Result + '] of ';
  end;
end;

function TAPData.GetNamePrefix: AnsiString;
begin
  Result:= StringOfChar('P', PointerCount);
end;

function TAPData.GetNameSuffix: AnsiString;
var
  i: Integer;
begin
  Result:= '';
  if ArraySpecific <> nil then begin
    Result:= IntToStr(ArraySpecific[0]);
    for i := 1 to High(ArraySpecific) do
      Result:= Result + '_' + IntToStr(ArraySpecific[i]);
    Result:= Result + 'v';
  end;
end;

class operator TAPData.NotEqual(const A, B: TAPData): Boolean;
begin
  Result:= not (A = B);
end;

{ TGeneratorOptions }

function TGeneratorOptions.IsSetExcluded(const Name: string): Boolean;
var i: Integer;
begin
  for i := 0 to High(CustomExcludedSets) do
    if CustomExcludedSets[i] = Name then
      Exit(True);
  Result:= False;
end;

end.
