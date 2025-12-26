pub type Wav {
  Wav(sample_rate: Int, channels: Int, bits: Bits, samples: List(Int))
}

pub type Bits {
  U8
  I16
  I24
  F32
}
