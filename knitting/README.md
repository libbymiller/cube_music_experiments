# ABOUT

This generates a 2D csv file with 0 and 1 only and optional image, normalised from a csv 
column containing list of values.

WIP obvs.

Idea is to use it with this: 
https://github.com/libbymiller/ayab-commandline/blob/master/ayab_commandline_csv.py

# INSTALL

pip3 install numpy Pillow 


# RUN

```
Usage: create_cube_csv.py [filename] [options]

Takes a column of csv data and turns it into a density csv file

Options:
  -h, --help            show this help message and exit
  -i INPUT_FILE, --input=INPUT_FILE
                        input csv filename [default: Cube_knitting_Nov_2024 -
                        all_data.csv]
  -o OUTPUT_FILE, --output=OUTPUT_FILE
                        output csv filename [default: cube_results.csv]
  -l, --list            List csv file headers and exit [default: False]
  -x, --image           Save as an image as well [default: False]
  -f FIELD_NAME, --field=FIELD_NAME
                        Set the field name to convert [default: bar]
  -r REPEAT_LENGTH, --repeat=REPEAT_LENGTH
                        Set the repeat length of the pattern [default: 100]
  -d, --debug           Verbosity / debug [default: False]
  -m MAX_LENGTH, --max=MAX_LENGTH
                        Set the max length of the pattern [default: 200]
```
