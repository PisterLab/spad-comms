# Python
This contains all the Python scripts associated with the pulse-position modulation portion of the project.

# Table of Contents
[ppm_filegen.py](#ppm_filegen)

<a name="ppm_filegen"></a>
## ppm_filegen.py
For generating received data to run in conjunction with demodulator Verilog testbenches. I tried to be descriptive in the comments for what each function does.
### Functions of Interest:
* `rx_uniform`
* `rx_rand_data`
### How to Use:
1. At the very bottom of the file, modify the portion after `if __name__ == "__main__"` to use whichever functions you need with whatever parameters you need.
2. In Terminal: `python ppm_filegen.py`
