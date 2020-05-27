import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'util/bigint.dart';
import 'util/mutable_iterable.dart';

class ASN1Type {
  final int tag;

  final String name;

  const ASN1Type(this.tag, this.name);

  @override
  bool operator ==(other) {
    if (other is ASN1Type) {
      return other.tag == tag;
    } else if (other is int) {
      return other == tag;
    }

    return false;
  }

  static const endOfContentTag = 0x00;
  static const booleanTag = 0x01;
  static const integerTag = 2;
  static const bitStringTag = 3;
  static const octetStringTag = 4;
  static const nullTag = 5;
  static const objectIdentifierTag = 6;
  static const sequenceTag = 0x30;
  static const setTag = 0x31;
  static const printableStringTag = 19;
  static const T61StringTag = 20;
  static const IA5StringTag = 22;
  static const UTCTimeTag = 23;
}

abstract class ASN1Object {
  factory ASN1Object.decode(/* Iterable<int> | String */ input) {
    if (input is String) input = base64Decode(input);
    return parse(MutableIterable(input));
  }

  int get tag;

  Uint8List encode();

  static List<int> encodeLength(int length) {
    if (length <= 127) {
      return <int>[length];
    }
    final bytes = bigIntToBytes(BigInt.from(length));
    return <int>[
      bytes.length | 0x80,
      ...bytes,
    ];
  }

  static BigInt decodeLength(final MutableIterable input) {
    if (input.isEmpty) {
      throw Exception('Invalid data');
    }

    if ((input.first & 0x80) == 0) {
      final ret = BigInt.from(input.first);
      input.mutate = input.skip(1);
      return ret;
    }

    int numBytes = input.first & 0x7F;
    input.mutate = input.skip(1);
    if (input.length < numBytes) {
      throw Exception('Invalid data');
    }
    final ret = bytesToBigInt(input.take(numBytes));

    input.mutate = input.skip(numBytes);
    return ret;
  }

  static Uint8List pack(int tag, Iterable<int> content) {
    // TODO check tag is octect

    final encodedLength = ASN1Object.encodeLength(content.length);

    final ret = Uint8List(1 + encodedLength.length + content.length);
    ret[0] = tag;
    ret.setRange(1, 1 + encodedLength.length, encodedLength);
    ret.setRange(1 + encodedLength.length, ret.length, content);

    return ret;
  }

  static ASN1Object parse(final MutableIterable bytes) {
    if (bytes.isEmpty) {
      throw Exception('Invalid data');
    }

    switch (bytes.first) {
      case ASN1Type.sequenceTag:
        return ASN1Sequence.parse(bytes);
      case ASN1Type.booleanTag:
        return ASN1Boolean.parse(bytes);
      case ASN1Type.integerTag:
        return ASN1Integer.parse(bytes);
      case ASN1Type.nullTag:
        return ASN1Null.parse(bytes);
      case ASN1Type.octetStringTag:
        return ASN1OctetString.parse(bytes);
      case ASN1Type.objectIdentifierTag:
        return ASN1ObjectIdentifier.parse(bytes);
      case ASN1Type.bitStringTag:
        return ASN1BitString.parse(bytes);
      case ASN1Type.endOfContentTag:
        return ASN1EndOfContent.parse(bytes);
      default:
        throw UnimplementedError();
    }
  }
}

typedef ASN1Parser = ASN1Object Function(MutableIterable bytes,
    {Map<int, dynamic> parsers});

class ASN1EndOfContent implements ASN1Object {
  @override
  final int tag = ASN1Type.endOfContentTag;

  const ASN1EndOfContent();

  factory ASN1EndOfContent.decode(final Iterable<int> bytes) =>
      parse(MutableIterable(bytes));

  static ASN1EndOfContent parse(final MutableIterable bytes) {
    if (bytes.length < 2) {
      throw Exception('Invalid data!');
    }

    int tag = bytes.first;
    if (tag != ASN1Type.endOfContentTag) {
      throw Exception('Invalid tag!');
    }
    bytes.mutate = bytes.skip(1);

    if (bytes.first != 0) {
      throw Exception('Invalid length!');
    }
    bytes.mutate = bytes.skip(1);

    return ASN1EndOfContent();
  }

  @override
  Uint8List encode() {
    final ret = Uint8List(2);
    ret[0] = tag;
    ret[1] = 0;

    return ret;
  }

  @override
  bool operator ==(dynamic other) {
    return other is ASN1EndOfContent;
  }
}

class ASN1Sequence implements ASN1Object {
  @override
  final int tag = ASN1Type.sequenceTag;

  final List<ASN1Object> children;

  ASN1Sequence(Iterable<ASN1Object> children)
      : children = List<ASN1Object>.from(children);

  factory ASN1Sequence.decode(/* Iterable<int> | String */ bytes) => parse(
      MutableIterable(bytes is Iterable<int> ? bytes : base64Decode(bytes)));

  static ASN1Sequence parse(final MutableIterable bytes) {
    if (bytes.length < 3) {
      throw Exception('Invalid data!');
    }

    int tag = bytes.first;
    if (tag != ASN1Type.sequenceTag) {
      throw Exception('Invalid tag!');
    }
    bytes.mutate = bytes.skip(1);

    final children = <ASN1Object>[];

    if (bytes.first != 0x80) {
      final lengthBigInt = ASN1Object.decodeLength(bytes);
      int length = lengthBigInt.toInt();
      if (length == 0) {
        throw Exception('Invalid data');
      }

      if (bytes.length < length) {
        throw Exception('Invalid data');
      }

      final contentBytes = MutableIterable(bytes.take(length));
      bytes.mutate = bytes.skip(length);

      while (contentBytes.isNotEmpty) {
        children.add(ASN1Object.parse(contentBytes));
      }

      return ASN1Sequence(children);
    }

    bytes.mutate = bytes.skip(1);
    bool foundEnd = false;

    while (bytes.isNotEmpty) {
      final child = ASN1Object.parse(bytes);
      if (child is ASN1EndOfContent) {
        foundEnd = true;
        break;
      }
      children.add(child);
    }

    if (!foundEnd) {
      throw Exception('Invalid data. End of content not found');
    }

    return ASN1Sequence(children);
  }

  @override
  Uint8List encode() {
    List<int> content = children.map((e) => e.encode()).fold(
        <int>[], (previousValue, element) => previousValue..addAll(element));

    return ASN1Object.pack(tag, content);
  }

  @override
  bool operator ==(dynamic other) {
    if (other is ASN1Sequence) {
      return IterableEquality<ASN1Object>().equals(other.children, children);
    }

    return false;
  }
}

class ASN1Boolean implements ASN1Object {
  @override
  final int tag = ASN1Type.booleanTag;

  bool value;

  ASN1Boolean(this.value);

  factory ASN1Boolean.decode(final Iterable<int> bytes) =>
      parse(MutableIterable(bytes));

  static ASN1Boolean parse(final MutableIterable bytes) {
    if (bytes.length < 3) {
      throw Exception('Invalid data!');
    }

    int tag = bytes.first;
    if (tag != ASN1Type.booleanTag) {
      throw Exception('Invalid tag!');
    }
    bytes.mutate = bytes.skip(1);

    if (bytes.first != 1) {
      throw Exception('Invalid length!');
    }
    bytes.mutate = bytes.skip(1);

    final ret = ASN1Boolean(bytes.first != 0);

    bytes.mutate = bytes.skip(1);

    return ret;
  }

  @override
  Uint8List encode() {
    final ret = Uint8List(3);
    ret[0] = tag;
    ret[1] = 1;
    ret[2] = value ? 0xFF : 0x00;

    return ret;
  }

  @override
  bool operator ==(dynamic other) {
    if (other is ASN1Boolean) return other.value == value;

    return false;
  }
}

class ASN1Integer implements ASN1Object {
  @override
  final int tag = ASN1Type.integerTag;

  BigInt value;

  ASN1Integer(this.value);

  ASN1Integer.fromNum(num value) : value = BigInt.from(value);

  factory ASN1Integer.decode(final Iterable<int> bytes) =>
      parse(MutableIterable(bytes));

  static ASN1Integer parse(final MutableIterable bytes) {
    if (bytes.length < 3) {
      throw Exception('Invalid data!');
    }

    int tag = bytes.first;
    if (tag != ASN1Type.integerTag) {
      throw Exception('Invalid tag!');
    }
    bytes.mutate = bytes.skip(1);

    final lengthBigInt = ASN1Object.decodeLength(bytes);
    int length = lengthBigInt.toInt();
    if (length == 0) {
      throw Exception('Invalid data');
    }

    if (bytes.length < length) {
      throw Exception('Invalid data');
    }

    final contentBytes = bytes.take(length);
    bytes.mutate = bytes.skip(length);

    BigInt value = bytesToBigInt(contentBytes);
    if ((contentBytes.first & 0x80) != 0) {
      value = value.toSigned(value.bitLength);
    }

    return ASN1Integer(value);
  }

  @override
  Uint8List encode() {
    Uint8List content = bigIntToBytes(value,
        outLen: value.isNegative
            ? null
            : value.bitLength % 8 == 0
                ? ((value.bitLength + 7) >> 3) + 1
                : null);
    return ASN1Object.pack(tag, content);
  }

  @override
  bool operator ==(dynamic other) {
    if (other is ASN1Integer) return other.value == value;

    return false;
  }
}

class ASN1Null implements ASN1Object {
  @override
  final int tag = ASN1Type.nullTag;

  const ASN1Null();

  factory ASN1Null.decode(final Iterable<int> bytes) =>
      parse(MutableIterable(bytes));

  static ASN1Null parse(final MutableIterable bytes) {
    if (bytes.length < 2) {
      throw Exception('Invalid data!');
    }

    int tag = bytes.first;
    if (tag != ASN1Type.nullTag) {
      throw Exception('Invalid tag!');
    }
    bytes.mutate = bytes.skip(1);

    if (bytes.first != 0) {
      throw Exception('Invalid length!');
    }
    bytes.mutate = bytes.skip(1);

    return ASN1Null();
  }

  @override
  Uint8List encode() {
    final ret = Uint8List(2);
    ret[0] = tag;
    ret[1] = 0;

    return ret;
  }

  @override
  bool operator ==(dynamic other) {
    return other is ASN1Null;
  }
}

class ASN1OctetString implements ASN1Object {
  @override
  final int tag = ASN1Type.octetStringTag;

  Uint8List value;

  ASN1OctetString(this.value);

  factory ASN1OctetString.decode(final Iterable<int> bytes) =>
      parse(MutableIterable(bytes));

  static ASN1OctetString parse(final MutableIterable bytes) {
    if (bytes.length < 2) {
      throw Exception('Invalid data!');
    }

    int tag = bytes.first;
    if (tag != ASN1Type.octetStringTag) {
      throw Exception('Invalid tag!');
    }
    bytes.mutate = bytes.skip(1);

    final lengthBigInt = ASN1Object.decodeLength(bytes);
    int length = lengthBigInt.toInt();
    if (length == 0) {
      return ASN1OctetString(Uint8List(0));
    }

    if (bytes.length < length) {
      throw Exception('Invalid data');
    }

    final contentBytes = bytes.take(length);
    bytes.mutate = bytes.skip(length);

    return ASN1OctetString(Uint8List.fromList(contentBytes.toList()));
  }

  @override
  Uint8List encode() {
    return ASN1Object.pack(tag, value);
  }

  @override
  bool operator ==(dynamic other) {
    if (other is ASN1OctetString) {
      return IterableEquality<int>().equals(other.value, value);
    }

    return false;
  }
}

class ASN1ObjectIdentifier implements ASN1Object {
  @override
  final int tag = ASN1Type.objectIdentifierTag;

  Uint32List objectIdentifier;

  ASN1ObjectIdentifier(this.objectIdentifier);

  factory ASN1ObjectIdentifier.fromList(List<int> input) {
    if (input.any((element) => element < 0)) {
      throw Exception('Negative sub-identifiers not allowed');
    }

    return ASN1ObjectIdentifier(Uint32List.fromList(input));
  }

  factory ASN1ObjectIdentifier.fromString(String input) {
    final components = input.split('.').map<int>((e) => int.parse(e)).toList();
    return ASN1ObjectIdentifier.fromList(components);
  }

  factory ASN1ObjectIdentifier.decode(final Iterable<int> bytes) =>
      parse(MutableIterable(bytes));

  static ASN1ObjectIdentifier parse(final MutableIterable bytes) {
    if (bytes.length < 2) {
      throw Exception('Invalid data!');
    }

    int tag = bytes.first;
    if (tag != ASN1Type.objectIdentifierTag) {
      throw Exception('Invalid tag!');
    }
    bytes.mutate = bytes.skip(1);

    final lengthBigInt = ASN1Object.decodeLength(bytes);
    int length = lengthBigInt.toInt();
    if (length == 0) {
      throw Exception('Invalid data');
    }

    if (bytes.length < length) {
      throw Exception('Invalid data');
    }
    final contentBytes = MutableIterable(bytes.take(length));
    bytes.mutate = bytes.skip(length);

    final subIdentifiers = <int>[0];

    while (contentBytes.isNotEmpty) {
      final decoded = _decodedSubIdentifier(contentBytes);
      subIdentifiers.add(decoded);
    }

    subIdentifiers[0] = subIdentifiers[1] ~/ 40;
    subIdentifiers[1] = subIdentifiers[1] % 40;

    return ASN1ObjectIdentifier(Uint32List.fromList(subIdentifiers));
  }

  static int _decodedSubIdentifier(final MutableIterable input) {
    int value = 0;

    while (true) {
      if (input.isEmpty) {
        throw Exception('Invalid data');
      }
      final d = input.first;
      input.mutate = input.skip(1);

      value <<= 7;
      value |= d & 0x7F;

      if ((d & 0x80) == 0) {
        break;
      }
    }

    return value;
  }

  static int _encodeSubIdentifier(int value, ByteData output) {
    if (value != 0) {
      int numBytes = (value.bitLength / 7).ceil();
      // TODO check length
      for (int i = numBytes - 1; i >= 0; i--) {
        output.setUint8(i, (value & 0x7F) | 0x80);
        value = value >> 7;
      }
      output.setUint8(numBytes - 1, output.getUint8(numBytes - 1) & 0x7F);

      return numBytes;
    } else {
      // TODO check length
      output.setUint8(0, 0);

      return 1;
    }
  }

  Uint8List encodeContent() {
    if (objectIdentifier.length < 2) {
      throw Exception('Object identifier sould have atleast 2 subcomponents');
    }

    if (objectIdentifier[0] >= 3) {
      throw Exception(
          'First subcomponent of Object identifier should be less that 3');
    }

    if (objectIdentifier[1] >= 40) {
      throw Exception(
          'Second subcomponent of Object identifier should be less that 40');
    }

    final first = objectIdentifier[0] * 40 + objectIdentifier[1];

    int length = objectIdentifier.skip(2).fold(
        0,
        (previousValue, element) =>
            previousValue +
            (element == 0 ? 1 : (element.bitLength / 7).ceil()));
    length += first == 0 ? 1 : (first.bitLength / 7).ceil();

    final ret = Uint8List(length);
    int offset = 0;
    offset += _encodeSubIdentifier(first, ret.buffer.asByteData(offset));

    for (int element in objectIdentifier.skip(2)) {
      offset += _encodeSubIdentifier(element, ret.buffer.asByteData(offset));
    }

    if (offset != length) {
      throw Exception('error in implementation');
    }

    return ret;
  }

  @override
  Uint8List encode() {
    final content = encodeContent();
    return ASN1Object.pack(tag, content);
  }

  String get objectIdentifierAsString => objectIdentifier.join('.');

  @override
  bool operator ==(dynamic other) {
    if (other is ASN1ObjectIdentifier) {
      return IterableEquality<int>()
          .equals(other.objectIdentifier, objectIdentifier);
    }

    return false;
  }
}

class ASN1BitString implements ASN1Object {
  @override
  final int tag = ASN1Type.bitStringTag;

  Uint8List bitString;

  int _unusedBits = 0;

  int get unusedBits => _unusedBits;

  set unusedBits(int value) {
    if (value < 0) {
      throw Exception('unused bits cannot be negative');
    } else if (value > 7) {
      throw Exception('unused bits cannot be larger than 7');
    }

    _unusedBits = value;
  }

  ASN1BitString(this.bitString, {int unusedBits = 0})
      : _unusedBits = unusedBits;

  factory ASN1BitString.decode(Iterable<int> bytes) =>
      parse(MutableIterable(bytes));

  static ASN1BitString parse(MutableIterable bytes) {
    if (bytes.length < 3) {
      throw Exception('Invalid data!');
    }

    int tag = bytes.first;
    if (tag != ASN1Type.bitStringTag) {
      throw Exception('Invalid tag!');
    }
    bytes.mutate = bytes.skip(1);

    final lengthBigInt = ASN1Object.decodeLength(bytes);
    int length = lengthBigInt.toInt();
    if (length == 0) {
      throw Exception('Invalid data');
    }

    if (bytes.length < length) {
      throw Exception('Invalid data');
    }
    Iterable<int> contentBytes = bytes.take(length);
    bytes.mutate = bytes.skip(length);

    int unusedBytes = contentBytes.first;
    contentBytes = contentBytes.skip(1);

    if (contentBytes.isEmpty && unusedBytes != 0) {
      throw Exception('Unused bytes is not 0 while bitstring is empty');
    }

    return ASN1BitString(Uint8List.fromList(contentBytes.toList()),
        unusedBits: unusedBytes);
  }

  Iterable<int> encodeContent() {
    if (bitString.isEmpty && unusedBits != 0) {
      throw Exception('Unused bytes is not 0 while bitstring is empty');
    }
    return <int>[
      unusedBits,
      ...bitString,
    ];
  }

  @override
  Uint8List encode() {
    Iterable<int> content = encodeContent();
    return ASN1Object.pack(tag, content);
  }

  @override
  bool operator ==(dynamic other) {
    if (other is ASN1BitString) {
      return other.unusedBits == unusedBits &&
          IterableEquality<int>().equals(other.bitString, bitString);
    }

    return false;
  }
}

class ASN1Unknown implements ASN1Object {
  @override
  int tag;

  Uint8List value;

  ASN1Unknown(this.tag, this.value);

  factory ASN1Unknown.decode(final Iterable<int> bytes) =>
      parse(MutableIterable(bytes));

  static ASN1Unknown parse(final MutableIterable bytes) {
    if (bytes.length < 2) {
      throw Exception('Invalid data!');
    }

    int tag = bytes.first;
    bytes.mutate = bytes.skip(1);

    final lengthBigInt = ASN1Object.decodeLength(bytes);
    int length = lengthBigInt.toInt();
    if (length == 0) {
      throw Exception('Invalid data');
    }

    if (bytes.length < length) {
      throw Exception('Invalid data');
    }

    final contentBytes = bytes.take(length).toList();
    bytes.mutate = bytes.skip(length);

    return ASN1Unknown(tag & 0x3F, Uint8List.fromList(contentBytes));
  }

  @override
  Uint8List encode() {
    return ASN1Object.pack(tag, value);
  }
}

// TODO IA5String

// TODO utf8String

// TODO set

// TODO UtcTime

// TODO enumerated
