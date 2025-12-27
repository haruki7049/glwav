pub type Wave {
  Wave(sample_rate: Int, channels: Int, bits: Bits, samples: List(Float))
}

pub type Bits {
  U8
  I16
  I24
  F32
}

pub fn from_bit_array(bits: BitArray) -> Wave {
  todo
}
