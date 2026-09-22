import unittest
from bin_to_mem import encode


class MemoryImageTests(unittest.TestCase):
    def test_instruction_word_order_and_nop_padding(self):
        self.assertEqual(encode(bytes.fromhex("93005000"), 2), "00500093\n00000013\n")

    def test_byte_array_order_and_padding(self):
        self.assertEqual(encode(bytes.fromhex("93005000"), 2, "bytes"),
                         "93\n00\n50\n00\n13\n00\n00\n00\n")

    def test_bad_images_are_rejected(self):
        for data, depth in [(b"", 1), (b"\x13", 1), (b"\x00" * 8, 1),
                            (b"\x00" * 4, 0)]:
            with self.subTest(data=data, depth=depth):
                with self.assertRaises(ValueError):
                    encode(data, depth)

    def test_unknown_format_is_rejected(self):
        with self.assertRaises(ValueError):
            encode(b"\x00" * 4, 1, "bad")


if __name__ == "__main__":
    unittest.main()
