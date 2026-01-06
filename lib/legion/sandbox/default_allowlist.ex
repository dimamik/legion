defmodule Legion.Sandbox.DefaultAllowlist do
  @moduledoc """
  Default allowlist for sandboxed code execution.

  Replicates the safe subset of modules/functions that Dune allows,
  providing access to standard library functions while blocking
  dangerous operations like file I/O, process spawning, and code evaluation.
  """
  use Legion.Sandbox.Allowlist

  # Kernel - safe subset (operators, guards, basic functions)
  # Note: apply, spawn, send, etc. are blocked by AST analyzer
  allow(Kernel,
    only: [
      # Operators
      :|>,
      :+,
      :++,
      :-,
      :--,
      :*,
      :**,
      :/,
      :<>,
      :==,
      :===,
      :!=,
      :!==,
      :=~,
      :>,
      :>=,
      :<,
      :<=,
      :and,
      :or,
      :&&,
      :||,
      :!,
      :..,
      :..//,
      :not,
      :in,
      # Type checks
      :is_integer,
      :is_binary,
      :is_bitstring,
      :is_atom,
      :is_boolean,
      :is_float,
      :is_number,
      :is_list,
      :is_map,
      :is_map_key,
      :is_nil,
      :is_reference,
      :is_tuple,
      :is_exception,
      :is_struct,
      :is_function,
      # Control flow
      :if,
      :unless,
      :match?,
      :then,
      :tap,
      :raise,
      # Data manipulation
      :abs,
      :binary_part,
      :bit_size,
      :byte_size,
      :ceil,
      :div,
      :elem,
      :floor,
      :get_and_update_in,
      :get_in,
      :hd,
      :length,
      :make_ref,
      :map_size,
      :max,
      :min,
      :pop_in,
      :put_elem,
      :put_in,
      :rem,
      :round,
      :self,
      :tl,
      :trunc,
      :tuple_size,
      :update_in,
      :inspect,
      :to_string,
      :to_charlist,
      :throw,
      :dbg,
      # Sigils
      :sigil_C,
      :sigil_D,
      :sigil_N,
      :sigil_R,
      :sigil_S,
      :sigil_T,
      :sigil_U,
      :sigil_c,
      :sigil_r,
      :sigil_s,
      :sigil_w,
      :sigil_W
    ]
  )

  # Data structure modules
  allow(Access, :all)
  allow(Enum, :all)
  allow(Stream, :all)
  allow(Map, :all)
  allow(MapSet, :all)
  allow(Keyword, :all)
  allow(Tuple, :all)
  allow(Range, :all)
  allow(List, except: [:to_atom, :to_existing_atom])
  allow(String, except: [:to_atom, :to_existing_atom])

  # Numeric modules
  allow(Integer, :all)
  allow(Float, :all)
  allow(Bitwise, :all)

  # Date/Time modules
  allow(Date, :all)
  allow(DateTime, :all)
  allow(NaiveDateTime, :all)
  allow(Time, :all)
  allow(Calendar, except: [:put_time_zone_database])
  allow(Calendar.ISO, :all)

  # Encoding/URI modules
  allow(Base, :all)
  allow(URI, :all)
  allow(Version, :all)

  # Regex
  allow(Regex, :all)

  # Limited modules
  allow(Function, only: [:identity])
  allow(IO, only: [:iodata_length, :iodata_to_binary, :puts, :inspect])
  allow(Process, only: [:sleep])

  # Erlang modules
  allow(:math, :all)
  allow(:binary, :all)
  allow(:lists, :all)
  allow(:maps, :all)
  allow(:array, :all)
  allow(:gb_sets, :all)
  allow(:gb_trees, :all)
  allow(:ordsets, :all)
  allow(:orddict, :all)
  allow(:proplists, :all)
  allow(:queue, :all)
  allow(:string, :all)
  allow(:rand, :all)
  allow(:zlib, only: [:zip, :unzip, :gzip, :gunzip, :compress, :uncompress])

  # Erlang :erlang module - safe subset
  allow(:erlang,
    only: [
      :*,
      :+,
      :++,
      :-,
      :--,
      :/,
      :"/=",
      :<,
      :"=/=",
      :"=:=",
      :"=<",
      :==,
      :>,
      :>=,
      :abs,
      :adler32,
      :adler32_combine,
      :and,
      :append_element,
      :band,
      :binary_part,
      :binary_to_float,
      :binary_to_integer,
      :binary_to_list,
      :bit_size,
      :bitstring_to_list,
      :bnot,
      :bor,
      :bsl,
      :bsr,
      :bxor,
      :byte_size,
      :ceil,
      :convert_time_unit,
      :crc32,
      :crc32_combine,
      :date,
      :delete_element,
      :div,
      :element,
      :float,
      :float_to_binary,
      :float_to_list,
      :floor,
      :hd,
      :insert_element,
      :integer_to_binary,
      :integer_to_list,
      :iolist_size,
      :iolist_to_binary,
      :iolist_to_iovec,
      :is_atom,
      :is_binary,
      :is_bitstring,
      :is_boolean,
      :is_float,
      :is_function,
      :is_integer,
      :is_list,
      :is_map,
      :is_map_key,
      :is_number,
      :is_pid,
      :is_port,
      :is_record,
      :is_reference,
      :is_tuple,
      :length,
      :list_to_binary,
      :list_to_bitstring,
      :list_to_float,
      :list_to_integer,
      :localtime,
      :localtime_to_universaltime,
      :make_ref,
      :make_tuple,
      :map_get,
      :map_size,
      :max,
      :md5,
      :md5_final,
      :md5_init,
      :md5_update,
      :min,
      :monotonic_time,
      :not,
      :or,
      :phash2,
      :ref_to_list,
      :rem,
      :round,
      :setelement,
      :size,
      :split_binary,
      :system_time,
      :time,
      :time_offset,
      :timestamp,
      :tl,
      :trunc,
      :tuple_size,
      :tuple_to_list,
      :unique_integer,
      :universaltime,
      :universaltime_to_localtime,
      :xor
    ]
  )

  # Erts debug - very limited
  allow(:erts_debug, only: [:same, :size, :size_shared])
end
