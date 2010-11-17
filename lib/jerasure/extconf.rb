#extconf.rb
require 'mkmf'


#if have_library('Jerasure-1.2/cauchy.h') &&
#   have_header('Jerasure-1.2/galois.h') &&
#   have_header('Jerasure-1.2/jerasure.h') &&
#   have_header('Jerasure-1.2/liberation.h') &&
#   have_header('Jerasure-1.2/reed_sol.h')
#if have_library('Jerasure-1.2')
#dir_config('jerasure')
#if have_header('cauchy.h') &&
#   have_header('galois.h') &&
#   have_header('jerasure.h') &&
#   have_header('liberation.h') &&
#   have_header('reed_sol.h') &&
#   have_library('liberation','liberation_coding_bitmatrix')
#  create_makefile('parity_calc')
#else
#  puts "Unable to include all headers"
#end

create_makefile('parity_calc')

