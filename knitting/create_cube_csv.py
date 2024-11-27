import csv
from optparse import OptionParser
import sys
from PIL import Image
import numpy
import math


debug = False

# read header file only
def read_header(data_filename):
    data = []
    with open(data_filename) as csv_file:
       # reads in the file and makes a dictionary, keyed off the first row
       reader = csv.DictReader(csv_file, delimiter=',')
       print("fieldnames",reader.fieldnames)


# read all data specified by header and return
def read_data(data_filename,field):
    data = []
    with open(data_filename) as csv_file:
       # reads in the file and makes a dictionary, keyed off the first row
       reader = csv.DictReader(csv_file, delimiter=',')
       print("fieldnames",reader.fieldnames)
       for row in reader:
           try:
               f = (int(float(row[field])))
               data.append(f)
           except ValueError:
               if(debug):
                   print("attempt to parse",row[field],"as int failed")
               data.append(0)

    print("data for",field,"is",data)
    return data


# https://www.geeksforgeeks.org/python-program-to-find-closest-number-in-array/
def find_closest_value(givenList, target):
    
    def difference(givenList):
        return abs(givenList - target)
    
    result = min(givenList, key=difference)
    return int(result)


def normalise(data):
    #print(data)
    scaled_data = []

    # avoiding divide by 0
    raw_data_min = 1
    raw_data_max = max(data)

    # for now, hardcoded
    min_density = 1
    max_density = len(data)

    #just generates a list of numbers 
    density_key = list(range(min_density,max_density))

    factor = (raw_data_max - raw_data_min)/(max_density - min_density)

    for money in data:
        scaled_money = money/factor
        if(scaled_money != 0):
            scaled_money = scaled_money
            result = find_closest_value(density_key,scaled_money)
            scaled_data.append(result)
        else:
            scaled_data.append(1)

    print("scaled_data",scaled_data)
    return scaled_data


def generate_density_fragment(density, max_length, repeat_length):
    arr = []

    # we want a length of max_length
    for counter in range(1,max_length+1):
        # should round up
        # in any given repeat length, we get a 1 density numbers of times
        #print("density",density)
        freq = math.ceil(repeat_length/density)
        #print("freq",freq)
        # then we want to add it in if our counter is the same as that value
        hit = int(counter%freq)
        if(hit == 0):
            arr.append("1") 
        else:
            arr.append("0")
    if(debug):
        print("result for density:",density,"for repeat_len",repeat_length,"over density is freq:",freq,"is")
        print("".join(arr))
    return arr


def build_rows(scaled_data, max_length,repeat_length):
   rows = []

   for item in scaled_data:
      row = generate_density_fragment(item, max_length, repeat_length)
      rows.append(row)
   return rows


def save_csv(rows,output_filename):
    print("writing data to",output_filename)
    with open(output_filename, 'w', newline='') as csvfile:
        filewriter = csv.writer(csvfile, delimiter=',',
                            quotechar='|', quoting=csv.QUOTE_MINIMAL)
        for row in rows:
            filewriter.writerow(row)

def generate_image(array_of_rows,fn):

         new_arr = []
    
         w = 0
         h = 0

         # build a new array ensuring ints, and get with and height
         for r in array_of_rows:
            new_r = []
            for p in r:
               try:
                  int(p)
                  new_r.append(int(p))
               except ValueError:
                  pass
            new_arr.append(new_r)
            h = len(new_r)
      
         w = len(array_of_rows)
         if(debug):
             print("w",w,"h",h)
       
         numpy_csv = numpy.array(new_arr).astype("float")
         numpy_csv = numpy_csv.reshape((w,h)).astype('uint8')*255

         if(debug):
             print(numpy_csv)
    
         img = Image.fromarray(numpy_csv,mode='L')

         # we save it using the output filename with .png on the end
         img_ff = fn+'.png'
         print("writing image to",img_ff)
         img.save(img_ff)



if __name__ == '__main__':

    # Parse command line options
    parser = OptionParser("%prog [filename] [options]", \
        description = "Takes a column of csv data and turns it into a density csv file")
    parser.add_option("-i", "--input", \
        dest    = "input_file", \
        type    = "string", \
        default = "Cube_knitting_Nov_2024 - all_data.csv", \
        help    = "input csv filename [default: %default]")
    parser.add_option("-o", "--output", \
        dest    = "output_file", \
        type    = "string", \
        default = "cube_results.csv", \
        help    = "output csv filename [default: %default]")
    parser.add_option("-l", "--list", \
        dest    = "list", \
        action  ="store_true", \
        default = False, \
        help    = "List csv file headers and exit [default: %default]")
    parser.add_option("-x", "--image", \
        dest    = "image", \
        action  ="store_true", \
        default = False, \
        help    = "Save as an image as well [default: %default]")
    parser.add_option("-f", "--field", \
        dest    = "field_name", \
        default = "bar", \
        help    = "Set the field name to convert [default: %default]")
    parser.add_option("-r", "--repeat", \
        dest    = "repeat_length", \
        default = 100, \
        help    = "Set the repeat length of the pattern [default: %default]")
    parser.add_option("-d", "--debug", \
        dest    = "debug", \
        action  ="store_true", \
        default = False, \
        help    = "Verbosity / debug [default: %default]")
    parser.add_option("-m", "--max", \
        dest    = "max_length", \
        default = 200, \
        help    = "Set the max length of the pattern [default: %default]")

    (options, args) = parser.parse_args()

    if(options.debug):
        print(options)
        debug = True

    if options.list:
        print(read_header(options.input_file))
        sys.exit(0)

    data = read_data(options.input_file,options.field_name)    
    scaled_data = normalise(data)
    array_of_rows = build_rows(scaled_data,options.max_length,int(options.repeat_length))   
    save_csv(array_of_rows, options.output_file)

    if(options.image):
        generate_image(array_of_rows,options.output_file)
