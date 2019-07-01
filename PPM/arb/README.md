# Arbitrary Waveform Generator
This contains all the .arb files for the arbitrary waveform generator.

# Table of Contents
[Generating TX Data File](#tx_data_arb)

<a name="tx_data_arb"></a>
## Generating TX Data File
This section assumes you started with nothing (i.e. no binary file).
1. In the `../python` direcotry, there is a file `ppm_filegen.py`. At the bottom of the file after `if __name__ == ...`, modify the main method to use one of the RX binary file generators to create a binary file with the data.
2. In addition to your previous change, use `tx_data_arb()` to read in the file you'll generate in Step 1 and specify an output file along with the appropriate parameters.
3. In Terminal, `python ppm_filegen.py`
Congratulations! You're now the proud owner of a file you can give to the arbitrary waveform generator.
