#!/user/bin/env python3

# Script which runs daily to update staff print totals
# based on CSVs generated by the printer itself.

import sys
sys.path.insert(1, '../../python/')

import os
import re
import csv
import datetime

#import ECC
#import PDSChurch

from pprint import pprint
from pprint import pformat

###########################################################

def _strip(value):
    #The CSV puts brackets around values, which we don't want
    return value.strip('[').strip(']')

def compare_csvs(csv_new, csv_old):

    updated_printlog = list()

    for num, row in csv_new.items():
        if num in csv_old:
            row_old = csv_old[num]
            print_delta = row['total'] - row_old['total']
            print_black_delta = row['b&wtotal'] - row_old['b&wtotal']
            print_color_delta = row['colortotal'] - row_old['colortotal']
            updated_printlog.append({
                'User'                  : row['num'],
                'Name'                  : row['name'],
                'Total Prints'          : row['total'],
                'Prints Today'          : print_delta,
                'B & W Prints Total'    : row['b&wtotal'],
                'B & W Prints Today'    : print_black_delta,
                'Color Prints Total'    : row['colortotal'],
                'Color Prints Today'    : print_color_delta,
            })

    print(f'== Compared {len(csv_new)} staffers')
    return updated_printlog


def load_latest_csv():

    # loads a specific filename CSV
    def _load_ricoh_csv(filename):
        rows = list()
        with open(filename, "r", encoding='utf-8') as csvfile:
            csvreader = csv.DictReader(csvfile)
            for row in csvreader:
                stripped = dict()
                for key, value in row.items():
                    stripped[key] = value.strip(']').strip('[')
                rows.append(stripped)
        return rows

    today = datetime.date.today()
    datestring_new = f'{today.year}{today.month}{today.day}'
    datestring_old = f'{today.year}{today.month}{today.day - 1}'

    filename_new = f'RICOH IM C4500_usercounter_{datestring_new}.csv'
    filename_old = f'RICOH IM C4500_usercounter_{datestring_old}.csv'

    #NOTE: debug_filenames are only placeholders until we can
    #      automatically download the latest each day
    debug_filename_new = 'RICOH IM C4500_usercounter_20201013.csv'
    debug_filename_old = 'RICOH IM C4500_usercounter_20201011.csv'

    csv_rows_new = _load_ricoh_csv(debug_filename_new)
    csv_rows_old = _load_ricoh_csv(debug_filename_old)

    print(f"== Loaded {len(csv_rows_new)} staffers from latest CSV")
    print(f"== Loaded {len(csv_rows_old)} staffers from older CSV")
    return csv_rows_new, csv_rows_old

def extract_csv_data(csv_rows):

    def _extract_staffer(row):
        return {
            'num'           : row['User'],
            'name'          : _strip(row['Name']),
            'total'         : int(row['Total Prints'].strip()),
            'b&wtotal'      : int(row['B & W(Total Prints)'].strip()),
            'colortotal'    : int(row['Color(Total Prints)'].strip()),
        }

    csv_staffers = dict()

    for row in csv_rows:
        num = _strip(row['User'])
        this_staffer = _extract_staffer(row)
        csv_staffers[num] = this_staffer

    print(f"== Extracted {len(csv_staffers)} staffers")
    return csv_staffers

def write_printlogs(csv_new, csv_old, printlog):
    fieldnames = ['User', 'Name', 'Total Prints', 'Prints Today', 'B & W Prints Total', 'B & W Prints Today', 'Color Prints Total', 'Color Prints Today']
    filename = 'printlog.csv'

    with open(filename, "w+", encoding="utf-8", newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()

        #Write each staffer by User Number
        for staffer in printlog:
            writer.writerow(staffer)

    print(f"== Wrote {filename} with {len(printlog)} data rows")


def main():
    #log = ECC.setup_logging(debug=False)

    csv_rows_new, csv_rows_old = load_latest_csv()

    csv_new = extract_csv_data(csv_rows_new)
    csv_old = extract_csv_data(csv_rows_old)

    printlog = compare_csvs(csv_new, csv_old)

    write_printlogs(csv_new, csv_old, printlog)

main()