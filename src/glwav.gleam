import gleam/bit_array
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import glriff

pub type Wave {
  Wave(
    format_code: FormatCode,
    sample_rate: Int,
    channels: Int,
    bits: Bits,
    bytes_per_second: Int,
    block_align: Int,
    samples: List(Float),
  )
}

pub type Bits {
  U8
  I16
  I24
  F32
}

pub type FromBitArrayError {
  RiffFormatError(inner: glriff.FromBitArrayError)
  InvalidFormat
}

pub type FormatCode {
  PCM
  IeeeFloat
  Alaw
  Mulaw
  Extensible
}

pub type ChunkData {
  Fmt(
    format_code: FormatCode,
    sample_rate: Int,
    channels: Int,
    bytes_per_second: Int,
    block_align: Int,
    bits: Bits,
  )
  Data(data_bits: BitArray)
}

pub fn from_bit_array(bits: BitArray) -> Result(Wave, FromBitArrayError) {
  use riff_chunk: glriff.Chunk <- result.try(
    bits |> glriff.from_bit_array() |> result.map_error(RiffFormatError),
  )

  case riff_chunk {
    glriff.RiffChunk(_four_cc, chunks) -> {
      let chunk_data: List(Result(ChunkData, ReadChunkError)) =
        chunks
        |> list.map(fn(chunk) {
          case chunk {
            glriff.Chunk(four_cc: <<"fmt ">>, data: data) ->
              read_fmt_chunk(data)
            glriff.Chunk(four_cc: <<"data">>, data: data) ->
              read_data_chunk(data)
            _ -> Error(NotSupported)
          }
        })

      // from_bit_array 関数の todo 部分
      case chunk_data {
        [
          Ok(Fmt(
            format_code,
            sample_rate,
            channels,
            bytes_per_second,
            block_align,
            bits,
          )),
          Ok(Data(data_bits)),
          ..
        ] -> {
          let samples = case bits {
            U8 -> parse_u8_samples(data_bits)
            I16 -> parse_i16_samples(data_bits)
            I24 -> parse_i24_samples(data_bits)
            F32 -> parse_f32_samples(data_bits)
          }

          Ok(Wave(
            format_code: format_code,
            sample_rate: sample_rate,
            channels: channels,
            bits: bits,
            bytes_per_second: bytes_per_second,
            block_align: block_align,
            samples: samples,
          ))
        }
        _ -> Error(InvalidFormat)
      }
    }
    _ -> Error(InvalidFormat)
  }
}

pub type ReadChunkError {
  NotSupported
  InvalidFormatCode
  InvalidChannels
  InvalidSampleRate
  InvalidBytesPerSecond
  InvalidBlockAlign
  InvalidBits
}

fn read_fmt_chunk(data: BitArray) -> Result(ChunkData, ReadChunkError) {
  use format_code_bits: BitArray <- result.try(
    data |> bit_array.slice(0, 2) |> result.replace_error(InvalidFormatCode),
  )

  use channels_bits: BitArray <- result.try(
    data |> bit_array.slice(2, 2) |> result.replace_error(InvalidChannels),
  )

  use sample_rate_bits: BitArray <- result.try(
    data |> bit_array.slice(4, 4) |> result.replace_error(InvalidSampleRate),
  )

  use bytes_per_second_bits: BitArray <- result.try(
    data |> bit_array.slice(8, 4) |> result.replace_error(InvalidBytesPerSecond),
  )

  use block_align_bits: BitArray <- result.try(
    data |> bit_array.slice(12, 2) |> result.replace_error(InvalidBlockAlign),
  )

  use bits_bits: BitArray <- result.try(
    data |> bit_array.slice(14, 2) |> result.replace_error(InvalidBits),
  )

  use format_code: FormatCode <- result.try(
    format_code_bits |> convert_format_code(),
  )

  use channels: Int <- result.try(channels_bits |> convert_channels())

  use sample_rate: Int <- result.try(sample_rate_bits |> convert_sample_rate())

  use bytes_per_second: Int <- result.try(
    bytes_per_second_bits |> convert_bytes_per_second(),
  )

  use block_align: Int <- result.try(block_align_bits |> convert_block_align())

  use bits: Bits <- result.try(bits_bits |> convert_bits())

  Ok(Fmt(
    format_code,
    sample_rate,
    channels,
    bytes_per_second,
    block_align,
    bits,
  ))
}

fn convert_format_code(bits: BitArray) -> Result(FormatCode, ReadChunkError) {
  case bits {
    <<1:size(16)-little>> -> Ok(PCM)
    _ -> Error(NotSupported)
  }
}

fn convert_channels(bits: BitArray) -> Result(Int, ReadChunkError) {
  case bits {
    <<val:size(16)-little>> -> Ok(val)
    _ -> Error(InvalidChannels)
  }
}

fn convert_sample_rate(bits: BitArray) -> Result(Int, ReadChunkError) {
  case bits {
    <<val:size(32)-little>> -> Ok(val)
    _ -> Error(InvalidSampleRate)
  }
}

fn convert_bytes_per_second(bits: BitArray) -> Result(Int, ReadChunkError) {
  case bits {
    <<val:size(32)-little>> -> Ok(val)
    _ -> Error(InvalidBytesPerSecond)
  }
}

fn convert_block_align(bits: BitArray) -> Result(Int, ReadChunkError) {
  case bits {
    <<val:size(16)-little>> -> Ok(val)
    _ -> Error(InvalidBlockAlign)
  }
}

fn convert_bits(bits: BitArray) -> Result(Bits, ReadChunkError) {
  case bits {
    <<val:size(16)-little>> ->
      case val {
        8 -> Ok(U8)
        16 -> Ok(I16)
        24 -> Ok(I24)
        32 -> Ok(F32)
        _ -> Error(InvalidBits)
      }
    _ -> Error(InvalidBits)
  }
}

fn read_data_chunk(data: BitArray) -> Result(ChunkData, ReadChunkError) {
  Ok(Data(data_bits: data))
}

fn parse_u8_samples(data: BitArray) -> List(Float) {
  do_parse_u8_samples(data, [])
}

fn do_parse_u8_samples(data: BitArray, acc: List(Float)) -> List(Float) {
  case data {
    <<val:size(8)-unsigned, rest:bits>> -> {
      let normalized = { int.to_float(val) -. 128.0 } /. 128.0
      do_parse_u8_samples(rest, [normalized, ..acc])
    }
    _ -> list.reverse(acc)
  }
}

fn parse_i16_samples(data: BitArray) -> List(Float) {
  do_parse_i16_samples(data, [])
}

fn do_parse_i16_samples(data: BitArray, acc: List(Float)) -> List(Float) {
  case data {
    <<val:size(16)-signed-little, rest:bits>> -> {
      let normalized = int.to_float(val) /. 32_768.0
      do_parse_i16_samples(rest, [normalized, ..acc])
    }
    _ -> list.reverse(acc)
  }
}

fn parse_i24_samples(data: BitArray) -> List(Float) {
  do_parse_i24_samples(data, [])
}

fn do_parse_i24_samples(data: BitArray, acc: List(Float)) -> List(Float) {
  case data {
    <<val:size(24)-signed-little, rest:bits>> -> {
      let normalized = int.to_float(val) /. 8_388_608.0
      do_parse_i24_samples(rest, [normalized, ..acc])
    }
    _ -> list.reverse(acc)
  }
}

fn parse_f32_samples(data: BitArray) -> List(Float) {
  do_parse_f32_samples(data, [])
}

fn do_parse_f32_samples(data: BitArray, acc: List(Float)) -> List(Float) {
  case data {
    <<val:size(32)-float-little, rest:bits>> -> {
      do_parse_f32_samples(rest, [val, ..acc])
    }
    _ -> list.reverse(acc)
  }
}

pub fn to_bit_array(wave: Wave) -> BitArray {
  // Convert samples to binary data based on bit depth
  let data_bits = case wave.bits {
    U8 -> samples_to_u8(wave.samples)
    I16 -> samples_to_i16(wave.samples)
    I24 -> samples_to_i24(wave.samples)
    F32 -> samples_to_f32(wave.samples)
  }

  // Create fmt chunk
  let format_code_bits = case wave.format_code {
    PCM -> <<1:size(16)-little>>
    IeeeFloat -> <<3:size(16)-little>>
    Alaw -> <<6:size(16)-little>>
    Mulaw -> <<7:size(16)-little>>
    Extensible -> <<65_534:size(16)-little>>
  }

  let bits_value = case wave.bits {
    U8 -> 8
    I16 -> 16
    I24 -> 24
    F32 -> 32
  }

  let fmt_data = <<
    format_code_bits:bits,
    wave.channels:size(16)-little,
    wave.sample_rate:size(32)-little,
    wave.bytes_per_second:size(32)-little,
    wave.block_align:size(16)-little,
    bits_value:size(16)-little,
  >>

  let fmt_chunk = <<
    "fmt ":utf8,
    16:size(32)-little,
    fmt_data:bits,
  >>

  // Create data chunk
  let data_size = bit_array.byte_size(data_bits)
  let data_chunk = <<
    "data":utf8,
    data_size:size(32)-little,
    data_bits:bits,
  >>

  // Create RIFF header
  let chunks = <<fmt_chunk:bits, data_chunk:bits>>
  let riff_size = bit_array.byte_size(chunks) + 4
  <<
    "RIFF":utf8,
    riff_size:size(32)-little,
    "WAVE":utf8,
    chunks:bits,
  >>
}

fn samples_to_u8(samples: List(Float)) -> BitArray {
  samples
  |> list.fold(<<>>, fn(acc, sample) {
    let value = {
      sample *. 128.0 +. 128.0
    }
    let int_value = case value {
      v if v <. 0.0 -> 0
      v if v >. 255.0 -> 255
      v -> float_to_int(v)
    }
    <<acc:bits, int_value:size(8)>>
  })
}

fn samples_to_i16(samples: List(Float)) -> BitArray {
  samples
  |> list.fold(<<>>, fn(acc, sample) {
    let value = sample *. 32_768.0
    let int_value = case value {
      v if v <. -32_768.0 -> -32_768
      v if v >. 32_767.0 -> 32_767
      v -> float_to_int(v)
    }
    <<acc:bits, int_value:size(16)-little>>
  })
}

fn samples_to_i24(samples: List(Float)) -> BitArray {
  samples
  |> list.fold(<<>>, fn(acc, sample) {
    let value = sample *. 8_388_608.0
    let int_value = case value {
      v if v <. -8_388_608.0 -> -8_388_608
      v if v >. 8_388_607.0 -> 8_388_607
      v -> float_to_int(v)
    }
    <<acc:bits, int_value:size(24)-little>>
  })
}

fn samples_to_f32(samples: List(Float)) -> BitArray {
  samples
  |> list.fold(<<>>, fn(acc, sample) {
    <<acc:bits, sample:size(32)-float-little>>
  })
}

fn float_to_int(f: Float) -> Int {
  float.round(f)
}
