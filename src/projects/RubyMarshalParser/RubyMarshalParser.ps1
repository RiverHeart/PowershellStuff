# https://github.com/andrykonchin/marshal-parser

# Good guide to the Marshal format
# https://docs.ruby-lang.org/en/2.1.0/marshal_rdoc.html

# Good reference implementation of a RXData parser
# Particularly for the User Defined Objects
# https://github.com/GamingLiamStudios/rxdataToJSON/blob/develop/source/main.cpp

# Note: Ruby 1.8.1 chars are a single byte.

# MARK: NATIVE OBJECT

class RubyObject {
    [string] $Name = "Unknown"
    [char] $Type
    [hashtable] $Properties = @{}
    [hashtable] $Methods = @{}

    RubyObject([System.IO.BinaryReader] $Reader) {
        $this.Type = Assert-RubyType $Reader 'o'

        # Following the type byte is a symbol containing the class
        # name of the object.
        $this.Name = Read-RubyString $Reader

        # Following the class name is a long indicating the number of
        # instance variable names and values for the object.
        $PropCount = Read-RubyFixnum $Reader -NoTypeCheck

        Write-Verbose "Creating object '$($this.Name) with '$PropCount' instance variables."

        # Following the length is a set of name-value pairs.
        # The names are symbols while the values are objects.
        for ($i = 0; $i -lt $PropCount; $i++) {
            $PropName = Read-RubyString $Reader
            Write-Verbose "Processing property '$PropName' ($($i + 1)/$PropCount) for $($this.Name)"
            $PropValue = $this.Properties[$PropName] = Invoke-RubyParser $Reader
            Write-Verbose "Added property '$PropName=$PropValue' to $($this.Name)"
        }
    }
}

# MARK: USER OBJECT

class Table {
    [int32] $SizeX
    [int32] $SizeY
    [int32] $SizeZ

    [System.Collections.Generic.List[int16]] $Data

    Table() {}

    Table([System.IO.BinaryReader] $Reader) {

        # Following the type byte is a byte sequence
        # containing the string content.
        $ObjectLength = Read-RubyFixnum $Reader -NoTypeCheck

        # Why are we moving forward 4 bytes?
        #$Reader.BaseStream.Seek(4, [System.IO.SeekOrigin]::Current)

        # NOTE: This is currently reading ints way
        # too big to be correct
        # https://github.com/GamingLiamStudios/rxdataToJSON/blob/bf923a91ef79c12ba4447b02c051a547d3dc5529/source/reader/reader.cpp#L210
        $this.SizeX = $Reader.ReadInt32()
        $this.SizeY = $Reader.ReadInt32()
        $this.SizeZ = $Reader.ReadInt32()

        $SizeBytes = $Reader.ReadInt32()
        for ($i = 0; $i -lt $SizeBytes; $i++) {
            $this.Data[$i] = $Reader.ReadInt16()
        }
    }
}


# MARK: PARSERS

function Assert-RubyType {
    [OutputType([char])]
    param(
        [Parameter(Mandatory)]
        [System.IO.BinaryReader] $Reader,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $ExpectedTypes
    )

    $ActualType = $Reader.ReadChar()
    if ($ActualType -notin $ExpectedTypes) {
        throw [System.IO.InvalidDataException]::new("Expected type(s) ($($ExpectedTypes -join ' ')) but got '$ActualType' instead.")
    }
    return $ActualType
}

<#
.SYNOPSIS
    Reads a ruby object from a BinaryReader.

.DESCRIPTION
    Reads a ruby object from a BinaryReader.

    "o" represents an object that doesn't have any other special
    form (such as a user-defined or built-in format). Following the
    type byte is a symbol containing the class name of the object.

    Following the class name is a long indicating the number of
    instance variable names and values for the object. Double the
    given number of pairs of objects follow the size.

    The keys in the pairs must be symbols containing instance variable names.
#>

function Read-RubyObject {
    [OutputType([RubyObject])]
    param(
        [Parameter(Mandatory)]
        [System.IO.BinaryReader] $Reader
    )

    return [RubyObject]::new($Reader)
}

<#
.SYNOPSIS
    Reads a string, symbol, or symbol link from a BinaryReader.

.DESCRIPTION
    Reads a string, symbol, or symbol link from a BinaryReader.

    ":"" represents a real symbol. A real symbol contains the
    data needed to define the symbol for the rest of the stream
    as future occurrences in the stream will instead be references
    (a symbol link) to this one. The reference is a zero-indexed
    32 bit value (so the first occurrence of :hello is 0).

    Following the type byte is byte sequence which consists of a
    long indicating the number of bytes in the sequence followed
    by that many bytes of data. Byte sequences have no encoding.

    ";" represents a Symbol link which references a previously
    defined Symbol. Following the type byte is a long containing
    the index in the lookup table for the linked (referenced) Symbol.
#>
function Read-RubyString {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.IO.BinaryReader] $Reader
    )

    $Type = Assert-RubyType $Reader @(':', '"', ';')

    # ";" represents a Symbol link which references a previously defined Symbol.
    # Following the type byte is a long containing the index in the lookup table
    # for the linked (referenced) Symbol.
    if ($Type -eq ';') {
        $SymbolIndex = Read-RubyFixnum $Reader -NoTypeCheck
        try {
            $SymbolCache.Item($SymbolIndex)
        } catch {
            throw "SymbolCache of $($SymbolCache.Count) items failed lookup for index '$SymbolIndex'"
        }
        return
    }

    # Following the type byte is a byte sequence
    # containing the string content.
    $ByteSequence = Read-RubyFixnum $Reader -NoTypeCheck
    $Bytes = $Reader.ReadBytes($ByteSequence)

    # When dumped from ruby 1.9 an encoding instance
    # variable (:E) should be included unless the encoding is binary.
    $String = [System.Text.Encoding]::ASCII.GetString($Bytes)

    # Store a reference to symbols we've seen so we don't need
    # to backtrack.
    if ($Type -eq ':') {
        $Script:SymbolCache.Add($String)
    }

    return $String
}


<#
.SYNOPSIS
    Reads an array from a BinaryReader.

.DESCRIPTION
    Reads an array from a BinaryReader.

    "[" represents an Array. Following the type byte is
    a long indicating the number of objects in the array.
    The given number of objects follow the length.
#>
function Read-RubyArray {
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [System.IO.BinaryReader] $Reader
    )

    $Type = Assert-RubyType $Reader @('[')
    $ElementCount = Read-RubyFixnum $Reader -NoTypeCheck

    $Array = @()
    for($i = 0; $i -lt $ElementCount; $i++) {
        $Array += Invoke-RubyParser $Reader
    }
    return , $Array
}

<#
.SYNOPSIS
    Reads a hash from a BinaryReader.

.DESCRIPTION
    Reads a hash from a BinaryReader.

    "{" represents a Hash object while "}" represents a
    Hash with a default value set (Hash.new 0). Following
    the type byte is a long indicating the number of key-value
    pairs in the Hash, the size. Double the given number of
    objects follow the size.

    For a Hash with a default value, the default value follows all the pairs.
#>
function Read-RubyHash {
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [System.IO.BinaryReader] $Reader
    )

    $Type = Assert-RubyType $Reader @('{')

    # Following the type byte is a long indicating the
    # number of key-value pairs in the Hash, the size.
    $KeyValCount = Read-RubyFixnum $Reader -NoTypeCheck

    Write-Verbose "Creating hashtable with '$KeyValCount' instance variables."

    # Following the length is a set of name-value pairs.
    # The names are symbols while the values are objects.
    for ($i = 0; $i -lt $KeyValCount; $i++) {
        # Note: Hash keys can be integers
        $Key = Invoke-RubyParser $Reader
        Write-Verbose "Processing key '$Key' ($($i + 1)/$KeyValCount)"
        $Value = $this.Properties[$Key] = Invoke-RubyParser $Reader
        Write-Verbose "Added key '$Key=$Value' to $($this.Name)"
    }
}

function Convert-Endianness {
    param(
        [byte[]] $Bytes,

        [ValidateSet('Big', 'Little')]
        [string] $Endianness
    )

    $Buffer = [byte[]]::new(4)

    if ($Endianness -eq 'Big') {
        [Buffer]::BlockCopy($Bytes, 0, $Buffer, 1, 3)
        $Buffer[3] = 0
    }
    return $Buffer
}

function Get-SizeOf {
    [Alias('sizeof')]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject
    )

    return [System.BitConverter]::GetBytes($InputObject).length
}


<#
.SYNOPSIS
    Reads a fixnum from a BinaryReader.

.DESCRIPTION
    Reads a fixnum from a BinaryReader.

    "i" represents a signed 32 bit value using a packed format.
    One through five bytes follows the type. The value loaded
    will always be a Fixnum. On 32 bit platforms (where the
    precision of a Fixnum is less than 32 bits) loading large
    values will cause overflow on CRuby.

    The fixnum type is used to represent both ruby Fixnum objects
    and the sizes of marshaled arrays, hashes, instance variables
    and other types. In the following sections “long” will mean the
    format described below, which supports full 32 bit precision.

    The first byte has the following special values:

    x00 | Integer value is 0. No bytes follow.

    x01 | Total integer size is 2 bytes. Next byte is a positive integer in the range of 0 through 255.
          Only values between 123 and 255 should be represented this way to save bytes.

    xff | Total integer size is 2 bytes. Next byte is a negative integer in the range of -1 through -256.
    x02 | Total integer size is 3 bytes. Next 2 bytes are a positive little-endian integer.
    xfe | Total integer size is 3 bytes. Next 2 bytes are a negative little-endian integer.
    x03 | Total integer size is 4 bytes. Next 3 bytes are a positive little-endian integer.
    xfd | Total integer size is 2 bytes. Next 3 bytes are a negative little-endian integer.
    x04 | Total integer size is 5 bytes. Next 4 bytes are a positive little-endian integer.
          For compatibility with 32 bit ruby, only Fixnums less than 1073741824 should be represented this way.
          For sizes of stream objects full precision may be used.

    xfc | Total integer size is 2 bytes. Next 4 bytes are a negative little-endian integer.
          For compatibility with 32 bit ruby, only Fixnums greater than -10737341824 should be represented this way.
          For sizes of stream objects full precision may be used.

    Otherwise the first byte is a sign-extended eight-bit value with an offset.
    If the value is positive the value is determined by subtracting 5 from the value.
    If the value is negative the value is determined by adding 5 to the value.

    There are multiple representations for many values. CRuby always outputs the shortest representation possible.
#>
function Read-RubyFixnum {
    [OutputType([int32])]
    param(
        [Parameter(Mandatory)]
        [System.IO.BinaryReader] $Reader,

        [switch] $NoTypeCheck
    )

    # If we're consuming an 'i' object we want to consume
    # that char before reading further but in cases where the
    # next byte is known to be an int we should be able to ignore it.
    if (-not $NoTypeCheck) {
        $Type = $Reader.ReadChar()
        if ($Type -ne 'i') { throw [System.IO.InvalidDataException]::new("Expected type 'i', got '$Type' instead.") }
    }

    $Int32SizeBytes = 4
    [uint32] $Result = 0

    $Byte = $Reader.ReadByte()

    # The value of the integer is 0. No bytes follow.
    if ($Byte -eq 0) { return 0 }
    # Otherwise the first byte is a sign-extended eight-bit value with an offset.
    if ($Byte -gt 0) {
        # Positive Number

        # If the value is positive the value is determined by subtracting 5 from the value.
        if (4 -lt $Byte -and $Byte -lt 128) { return $Byte - 5 }

        # If we got this far, byte is likely 1-4 indicating the number of
        # remaing bytes to process into a int32 value. If the size is bigger
        # than we can store then we error out.
        if ($Byte -gt $Int32SizeBytes) { throw "Fixnum too big '$Byte'" }

        # Read the remaining bytes into an [int32] ($Result). Bitwise operators
        # only work on [int], hence the explicit cast.
        $Result = 0
        for ($i = 0; $i -lt $Int32SizeBytes; $i++) {
            $a = if ($i -lt $Byte) { $Reader.ReadByte() -shl 24 } else { 0 }
            $b = $Result -shr 8
            $Result = $a -bor $b
        }
    } else {
        # Negative Number

        # If the value is negative the value is determined by adding 5 to the value.
        if (-129 -lt $Byte -and $Byte -lt -4) { return $Byte + 5 }
        $Byte = -$Byte
        if ($Byte -gt $Int32SizeBytes) { throw "Fixnum too big '$Byte'" }

        $Result = [uint32]::MaxValue
        [uint32] $Mask = -bnot (0xff -shl 24)
        for ($i = 0; $i -lt $Int32Size; $i++) {
            $a = if ($i -lt $Byte) { [int] $Reader.ReadByte() -shl 24 } else { 0xff }
            $b = ($Result -shr 8) -band $Mask
            $Result = $a -bor $b
        }
    }

    return [byte] $Result
}

<#
.SYNOPSIS
    Reads a float from a BinaryReader.

.DESCRIPTION
    Reads a float from a BinaryReader.

    "f" represents a Float object. Following the type byte is
    a byte sequence containing the float value.

    The following values are special:

    "inf"  | Positive infinity
    "-inf” | Negative infinity
    "nan”  | Not a Number

    Otherwise the byte sequence contains a C double (loadable by strtod(3)).
    Older minor versions of Marshal also stored extra mantissa bits to ensure
    portability across platforms but 4.8 does not include these.
    See ruby-talk:69518 for some explanation
#>
function Read-RubyFloat {
    param(
        [Parameter(Mandatory)]
        [System.IO.BinaryReader] $Reader
    )

    Assert-RubyType -Reader $Reader -ExpectedTypes 'f' | Out-Null

    # Following the type byte is a byte sequence
    # containing the string content.
    $ByteSequence = Read-RubyFixnum $Reader -NoTypeCheck
    $Bytes = $Reader.ReadBytes($ByteSequence)

    # The value of the integer is 0. No bytes follow.
    if ($Byte -eq 0) { return 0 }
}

<#
.SYNOPSIS
    Reads a boolean or nil from a BinaryReader.

.DESCRIPTION
    Reads a boolean or nil from a BinaryReader.

    These objects are each one byte long.
    "T" is represents true, "F" represents false and "0" represents nil.
#>
function Read-RubyBoolAndNil {
    param(
        [Parameter(Mandatory)]
        [System.IO.BinaryReader] $Reader
    )

    $Type = Assert-RubyType -Reader $Reader -ExpectedTypes 'T', 'F', '0'
    if ($Type -eq 'T') { return $True }
    elseif ($Type -eq 'F') { return $False }
    elseif ($Type -eq '0') { return $Null }
    else { throw 'Encountered unknown error parsing bool/nil value.' }
}

<#
.SYNOPSIS
    Reads a User Defined object from a BinaryReader.

.DESCRIPTION
    Reads a User Defined object from a BinaryReader.

    "u" represents an object with a user-defined serialization format using
    the _dump instance method and _load class method. Following the type byte
    is a symbol containing the class name. Following the class name is a byte
    sequence containing the user-defined representation of the object.
#>
function Read-RubyUserObject {
    param(
        [Parameter(Mandatory)]
        [System.IO.BinaryReader] $Reader
    )

    $Type = Assert-RubyType -Reader $Reader -ExpectedTypes 'u' | Out-Null

    # Following the type byte is a symbol containing the class
    # name of the object.
    $Name = Read-RubyString $Reader

    Write-Verbose "Creating user defined object '$($this.Name)"

    $UserObject = $Script:UserObjects[$Name]
    if (-not $UserObject) {
        throw "Could not find a user defined object for '$Name'"
    }

    return $UserObject::new($Reader)
}

function Get-RubyParser {
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory)]
        [string] $Type
    )

    $Parser = $ParserTable["$ObjectType"]
    if (-not $Parser) {
        throw "Could not find a parser for object type '$ObjectType'"
    }

    return $Parser
}

function Invoke-RubyParser {
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [System.IO.BinaryReader] $Reader
    )

    # Each object in the stream is described by a byte indicating
    # its type followed by one or more bytes describing the object.
    # When "object" is mentioned it means any of the types that define a Ruby object.

    # Note: PeekChar returns int instead of char
    [char] $ObjectType = $Reader.PeekChar()
    $Parser = Get-RubyParser $ObjectType

    return $Parser.InvokeReturnAsIs($Reader)
}

# Using 'script' scope to make this available to the entire script/module
# although it really only needs to be accessed by Get-RubyParser.
#
# Using [System.Collections.Hashtable] instead of @{} to
# get a case-sensitive hashtable because some types share
# the same character in upper/lower case.
$Script:ParserTable = [System.Collections.Hashtable]::new()
$Script:ParserTable.Add('o', ${Function:Read-RubyObject})
$Script:ParserTable.Add('u', ${Function:Read-RubyUserObject})
$Script:ParserTable.Add(':', ${Function:Read-RubyString})
$Script:ParserTable.Add('"', ${Function:Read-RubyString})
$Script:ParserTable.Add(';', ${Function:Read-RubyString})
$Script:ParserTable.Add('i', ${Function:Read-RubyFixnum})
$Script:ParserTable.Add('f', ${Function:Read-RubyFloat})
$Script:ParserTable.Add('{', ${Function:Read-RubyHash})
$Script:ParserTable.Add('[', ${Function:Read-RubyArray})
$Script:ParserTable.Add('T', ${Function:Read-RubyBoolAndNil})
$Script:ParserTable.Add('F', ${Function:Read-RubyBoolAndNil})
$Script:ParserTable.Add('0', ${Function:Read-RubyBoolAndNil})

$Script:UserObjects = @{
    Table = [Table]
}

# Contains symbols encountered during parsing to resolve symbol links
#
# Using 'script' scope to make this available to the entire script/module
# Used by Read-RubyString.
$Script:SymbolCache = [System.Collections.Generic.List[string]]::new()

# Contains objects encountered during parsing to resolve object references
#
# Using 'script' scope to make this available to the entire script/module
# Used by Read-RubyObject and Read-RubyUserObject
$Script:ObjectCache = [System.Collections.Generic.List[string]]::new()

$VerbosePreference = 'Continue'
$FilePath = "./Documents/RPGXP/Test/Data/Map001.rxdata"
try {
    $File = [System.IO.File]::OpenRead($FilePath)
    $Reader = [System.IO.BinaryReader]::new($File)

    # The first two bytes of the stream contain the major and minor version,
    # each as a single byte encoding a digit. The version implemented in Ruby
    # is 4.8 (stored as “x04x08”) and is supported by ruby 1.8.0 and newer.
    $MajorVersion, $MinorVersion = $Reader.ReadBytes(2)
    if ($MajorVersion -ne 4 -and $MinorVersion -ne 8) {
        throw "Unsupported ruby marshal version $MajorVersion.$MinorVersion"
    }

    # Following the version bytes is a stream describing the serialized object.
    # The stream contains nested objects (the same as a Ruby object) but objects
    # in the stream do not necessarily have a direct mapping to the Ruby object model.
    #$EndOfFile = -1
    #$NextChar = $Reader.PeekChar()
    Invoke-RubyParser $Reader
} catch {
    Write-Host "Failed to parse file '$FilePath' at position '$($Reader.BaseStream.Position)' `n$_"
}
