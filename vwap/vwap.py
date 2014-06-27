#!/usr/bin/python -S

import os
import sys

def calc_vwap(row):
    for i in row:
        key = i[1]
        qty = int(i[2])
        price = float(i[3])
        multi = (qty * price)
        try:
            data[key] = [ data[key][0] + qty , data[key][1] + multi ]
        except KeyError:
            data[key] = [ qty, multi ]
        except NameError:
            data = { key: [ qty, multi ] }
        else:
            pass

    return [ [ i, data[i][0], round(data[i][1] / data[i][0], 2) ] for i in data ]

def main():
    for i in sys.argv[1:]:
        with open(i, 'r') as f:
            for line in f.readlines()[1:]:
                row = line[:-1].split()
                while True:
                    try:
                        data[row[0]].append(row)
                    except KeyError:
                        print date, calc_vwap(data[date])
                        del data
                        continue
                    except NameError:
                        data = { row[0]: [ row ] }
                        break
                    else:
                        break

                date = row[0]
                print ','.join(row)
        print date, calc_vwap(data[date])
    sys.exit(0)

if __name__ == '__main__':
    main()
