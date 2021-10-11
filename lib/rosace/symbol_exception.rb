require_relative '../rosace'
require_relative 'rtc_exception'

# Exception class for exceptions raised when symbols already exist or does not
# exist in a Context.
#
# @author AlexieVQ
class Rosace::SymbolException < Rosace::RTCException
end