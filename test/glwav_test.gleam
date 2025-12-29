import gleeunit
import gleeunit/should
import glwav

import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn make_wavefile_test() {
  let assert Ok(expected): Result(BitArray, simplifile.FileError) = simplifile.read_bits(from: "test/assets/test_data.wav")
  let wave: glwav.Wave =
      glwav.Wave(
        format_code: glwav.PCM,
        sample_rate: 44_100,
        channels: 1,
        bits: glwav.I16,
        bytes_per_second: 88_200,
        block_align: 2,
        samples: [
          0.0,
          0.02508544921875,
          0.049957275390625,
          0.074859619140625,
          0.09918212890625,
          0.1234130859375,
          0.1468505859375,
          0.170013427734375,
          0.1922607421875,
          0.21392822265625,
        ],
      )
  let wavedata: BitArray = wave |> glwav.to_bit_array()

  wavedata
  |> should.equal(expected)
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
        bytes_per_second: 88_200,
        block_align: 2,
        samples: [
          0.0,
          0.02508544921875,
          0.049957275390625,
          0.074859619140625,
          0.09918212890625,
          0.1234130859375,
          0.1468505859375,
          0.170013427734375,
          0.1922607421875,
          0.21392822265625,
        ],
      ),
    )

  wave
  |> should.equal(expected)
}
