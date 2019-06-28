# Verilog
This contains all of the source Verilog HDL associated with the pulse-position modulation portion of the project.

# Table of Contents
1. [Correlator](#ppm16_correlator)
2. [Demodulator](#ppm16_demod)

<a name="ppm16_correlator"></a>
## ppm16_correlator
The testbench for this is a very basic and fairly manual spot-testing mechanism for checking that the correlator for PPM functions as it should. The idea is that you feed it a set of 16 chips, and if the input is valid, the correlator spits out what the PPM symbol is.
### Associated Verilog
* `tb_ppm16_correlator.v`
* `ppm16_correlator.v`

<a name="ppm16_demod"></a>
## ppm16_demod
The associated testbench checks the functionality of the PPM demodulator. It includes packet detection with a method described in greater detail in the [Overleaf doc](https://www.overleaf.com/project/5ceff4266413dd65856e722e) under "Packet Structure".
### Associated Verilog
* `tb_ppm16_demod.v`
* `ppm16_demod.v`: You may need to modify the include statement to point to the correct location for `chips.vh`
* `ppm16_correlator.v`
* `chips.vh`
### Running the Testbench
1. In the `../python` directory, there is a file `ppm_filegen.py`. At the bottom of the file after `if __name__ == ...`, modify the main method to use whichever functions you need with whatever parameters you need.
2. In Terminal, `python ppm_filegen.py`.
3. Copy the output file into your `../verilog` directory.
4. In the `../verilog` directory, modify `tb_ppm16_demod.v` so CHIP_BITS, NUM_ROWS, and CHIPS_PER_ROW match with your settings in the Python script.
5. Run the testbench in the Verilog simulator of your choice.
