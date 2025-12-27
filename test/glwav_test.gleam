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
  let wave: glwav.Wave =
    wavefile
    |> glwav.from_bit_array()
  let expected: glwav.Wave =
    glwav.Wave(sample_rate: 44_100, channels: 1, bits: glwav.I16, samples: [])

  wave
  |> should.equal(expected)
}
