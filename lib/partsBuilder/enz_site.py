#!/usr/bin/env python

import argparse
from Bio import Restriction
from Bio.Restriction import *
from Bio.Seq import Seq
from Bio.Alphabet.IUPAC import IUPACAmbiguousDNA

#parsing params
def parse_options():
    parser = argparse.ArgumentParser()
    parser.add_argument("-seq", "--sequence", dest="sequence", help="necleotide sequence", type=str, required=True)
    parser.add_argument("-e", "--enzyme", dest="restriction_enzyme", help="restriction enzyme", type=str, required=True)
    return parser.parse_args()

def res_enz(seq, enzyme):
    exec 'sites = ' + enzyme + '.search(seq)'
    return sites

if __name__ == "__main__":
    args = parse_options()
    sites = res_enz(Seq(args.sequence, IUPACAmbiguousDNA()), args.restriction_enzyme)
    if sites:
        print sites
    else:
        print 'false'
        
