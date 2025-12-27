import gleam/bit_array
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
  Data(samples: List(Float))
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
          Ok(Data(samples)),
          ..
        ] ->
          Ok(Wave(
            format_code,
            sample_rate,
            channels,
            bits,
            bytes_per_second,
            block_align,
            samples,
          ))
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
    data |> bit_array.slice(2, 4) |> result.replace_error(InvalidChannels),
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
    channels,
    sample_rate,
    bytes_per_second,
    block_align,
    bits,
  ))
}

fn read_data_chunk(data: BitArray) -> Result(ChunkData, ReadChunkError) {
  todo
}

fn convert_format_code(bits: BitArray) -> Result(FormatCode, ReadChunkError) {
  case bits {
    <<1:size(4)-little>> -> Ok(PCM)
    _ -> Error(NotSupported)
  }
}

fn convert_channels(bits: BitArray) -> Result(Int, ReadChunkError) {
  case bits {
    <<val:little>> -> Ok(val)
    _ -> Error(InvalidChannels)
  }
}

fn convert_sample_rate(bits: BitArray) -> Result(Int, ReadChunkError) {
  case bits {
    <<val:little>> -> Ok(val)
    _ -> Error(InvalidSampleRate)
  }
}

fn convert_bytes_per_second(bits: BitArray) -> Result(Int, ReadChunkError) {
  case bits {
    <<val:little>> -> Ok(val)
    _ -> Error(InvalidBytesPerSecond)
  }
}

fn convert_block_align(bits: BitArray) -> Result(Int, ReadChunkError) {
  case bits {
    <<val:little>> -> Ok(val)
    _ -> Error(InvalidBlockAlign)
  }
}

fn convert_bits(bits: BitArray) -> Result(Bits, ReadChunkError) {
  case bits {
    <<val:little>> ->
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
