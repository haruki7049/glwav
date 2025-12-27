import gleeunit
import gleeunit/should
import glwav

import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn load_wavefile_test() {
  let assert Ok(wavefile): Result(BitArray, simplifile.FileError) =
    simplifile.read_bits(from: "test/assets/test_data.wav")
  let wave: Result(glwav.Wave, glwav.FromBitArrayError) =
    wavefile
    |> glwav.from_bit_array()
  let expected =
    Ok(
      glwav.Wave(
        format_code: glwav.PCM,
        sample_rate: 44_100,
        channels: 1,
        bits: glwav.I16,
        bytes_per_second: 0,
        block_align: 0,
        samples: [],
      ),
    )

  wave
  |> should.equal(expected)
}
