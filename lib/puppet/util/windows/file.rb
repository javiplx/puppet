require 'puppet/util/windows'

module Puppet::Util::Windows::File
  require 'ffi'
  extend FFI::Library
  extend Puppet::Util::Windows::String

  FILE_ATTRIBUTE_READONLY      = 0x00000001

  SYNCHRONIZE                 = 0x100000
  STANDARD_RIGHTS_REQUIRED    = 0xf0000
  STANDARD_RIGHTS_READ        = 0x20000
  STANDARD_RIGHTS_WRITE       = 0x20000
  STANDARD_RIGHTS_EXECUTE     = 0x20000
  STANDARD_RIGHTS_ALL         = 0x1F0000
  SPECIFIC_RIGHTS_ALL         = 0xFFFF

  FILE_READ_DATA               = 1
  FILE_WRITE_DATA              = 2
  FILE_APPEND_DATA             = 4
  FILE_READ_EA                 = 8
  FILE_WRITE_EA                = 16
  FILE_EXECUTE                 = 32
  FILE_DELETE_CHILD            = 64
  FILE_READ_ATTRIBUTES         = 128
  FILE_WRITE_ATTRIBUTES        = 256

  FILE_ALL_ACCESS = STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0x1FF

  FILE_GENERIC_READ =
     STANDARD_RIGHTS_READ |
     FILE_READ_DATA |
     FILE_READ_ATTRIBUTES |
     FILE_READ_EA |
     SYNCHRONIZE

  FILE_GENERIC_WRITE =
     STANDARD_RIGHTS_WRITE |
     FILE_WRITE_DATA |
     FILE_WRITE_ATTRIBUTES |
     FILE_WRITE_EA |
     FILE_APPEND_DATA |
     SYNCHRONIZE

  FILE_GENERIC_EXECUTE =
     STANDARD_RIGHTS_EXECUTE |
     FILE_READ_ATTRIBUTES |
     FILE_EXECUTE |
     SYNCHRONIZE

  def replace_file(target, source)
    target_encoded = wide_string(target.to_s)
    source_encoded = wide_string(source.to_s)

    flags = 0x1
    backup_file = nil
    result = ReplaceFileW(
      target_encoded,
      source_encoded,
      backup_file,
      flags,
      FFI::Pointer::NULL,
      FFI::Pointer::NULL
    )

    return true if result != FFI::WIN32_FALSE
    raise Puppet::Util::Windows::Error.new("ReplaceFile(#{target}, #{source})")
  end
  module_function :replace_file

  def move_file_ex(source, target, flags = 0)
    result = MoveFileExW(wide_string(source.to_s),
                         wide_string(target.to_s),
                         flags)

    return true if result != FFI::WIN32_FALSE
    raise Puppet::Util::Windows::Error.
      new("MoveFileEx(#{source}, #{target}, #{flags.to_s(8)})")
  end
  module_function :move_file_ex

  def symlink(target, symlink)
    flags = File.directory?(target) ? 0x1 : 0x0
    result = CreateSymbolicLinkW(wide_string(symlink.to_s),
      wide_string(target.to_s), flags)
    return true if result != FFI::WIN32_FALSE
    raise Puppet::Util::Windows::Error.new(
      "CreateSymbolicLink(#{symlink}, #{target}, #{flags.to_s(8)})")
  end
  module_function :symlink

  INVALID_FILE_ATTRIBUTES = 0xFFFFFFFF #define INVALID_FILE_ATTRIBUTES (DWORD (-1))

  def get_file_attributes(file_name)
    Puppet.deprecation_warning('Puppet::Util::Windows::File.get_file_attributes is deprecated; please use Puppet::Util::Windows::File.get_attributes')
    get_attributes(file_name)
  end
  module_function :get_file_attributes

  def get_attributes(file_name)
    result = GetFileAttributesW(wide_string(file_name.to_s))
    return result unless result == INVALID_FILE_ATTRIBUTES
    raise Puppet::Util::Windows::Error.new("GetFileAttributes(#{file_name})")
  end
  module_function :get_attributes

  def add_attributes(path, flags)
    oldattrs = get_attributes(path)

    if (oldattrs | flags) != oldattrs
      set_attributes(path, oldattrs | flags)
    end
  end
  module_function :add_attributes

  def remove_attributes(path, flags)
    oldattrs = get_attributes(path)

    if (oldattrs & ~flags) != oldattrs
      set_attributes(path, oldattrs & ~flags)
    end
  end
  module_function :remove_attributes

  def set_attributes(path, flags)
    success = SetFileAttributesW(wide_string(path), flags) != FFI::WIN32_FALSE
    raise Puppet::Util::Windows::Error.new("Failed to set file attributes") if !success

    success
  end
  module_function :set_attributes

  #define INVALID_HANDLE_VALUE ((HANDLE)(LONG_PTR)-1)
  INVALID_HANDLE_VALUE = FFI::Pointer.new(-1).address
  def self.create_file(file_name, desired_access, share_mode, security_attributes,
    creation_disposition, flags_and_attributes, template_file_handle)

    result = CreateFileW(wide_string(file_name.to_s),
      desired_access, share_mode, security_attributes, creation_disposition,
      flags_and_attributes, template_file_handle)

    return result unless result == INVALID_HANDLE_VALUE
    raise Puppet::Util::Windows::Error.new(
      "CreateFile(#{file_name}, #{desired_access.to_s(8)}, #{share_mode.to_s(8)}, " +
        "#{security_attributes}, #{creation_disposition.to_s(8)}, " +
        "#{flags_and_attributes.to_s(8)}, #{template_file_handle})")
  end

  def self.get_reparse_point_data(handle, &block)
    # must be multiple of 1024, min 10240
    FFI::MemoryPointer.new(REPARSE_DATA_BUFFER.size) do |reparse_data_buffer_ptr|
      device_io_control(handle, FSCTL_GET_REPARSE_POINT, nil, reparse_data_buffer_ptr)
      yield REPARSE_DATA_BUFFER.new(reparse_data_buffer_ptr)
    end

    # underlying struct MemoryPointer has been cleaned up by this point, nothing to return
    nil
  end

  def self.device_io_control(handle, io_control_code, in_buffer = nil, out_buffer = nil)
    if out_buffer.nil?
      raise Puppet::Util::Windows::Error.new("out_buffer is required")
    end

    FFI::MemoryPointer.new(:dword, 1) do |bytes_returned_ptr|
      result = DeviceIoControl(
        handle,
        io_control_code,
        in_buffer, in_buffer.nil? ? 0 : in_buffer.size,
        out_buffer, out_buffer.size,
        bytes_returned_ptr,
        nil
      )

      if result == FFI::WIN32_FALSE
        raise Puppet::Util::Windows::Error.new(
          "DeviceIoControl(#{handle}, #{io_control_code}, " +
          "#{in_buffer}, #{in_buffer ? in_buffer.size : ''}, " +
          "#{out_buffer}, #{out_buffer ? out_buffer.size : ''}")
      end
    end

    out_buffer
  end

  FILE_ATTRIBUTE_REPARSE_POINT = 0x400
  def symlink?(file_name)
    begin
      attributes = get_attributes(file_name)
      (attributes & FILE_ATTRIBUTE_REPARSE_POINT) == FILE_ATTRIBUTE_REPARSE_POINT
    rescue
      # raised INVALID_FILE_ATTRIBUTES is equivalent to file not found
      false
    end
  end
  module_function :symlink?

  GENERIC_READ                  = 0x80000000
  FILE_SHARE_READ               = 1
  FILE_SHARE_WRITE              = 2
  OPEN_EXISTING                 = 3
  FILE_FLAG_OPEN_REPARSE_POINT  = 0x00200000
  FILE_FLAG_BACKUP_SEMANTICS    = 0x02000000

  def self.open_symlink(link_name)
    begin
      yield handle = create_file(
      link_name,
      GENERIC_READ,
      FILE_SHARE_READ,
      nil, # security_attributes
      OPEN_EXISTING,
      FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS,
      0) # template_file
    ensure
      FFI::WIN32.CloseHandle(handle) if handle
    end

    # handle has had CloseHandle called against it, so nothing to return
    nil
  end

  def readlink(link_name)
    link = nil
    open_symlink(link_name) do |handle|
      link = resolve_symlink(handle)
    end

    link
  end
  module_function :readlink

  def stat(file_name)
    file_name = file_name.to_s # accomodate PathName or String
    stat = File.stat(file_name)
    singleton_class = class << stat; self; end
    target_path = file_name

    if symlink?(file_name)
      target_path = readlink(file_name)
      link_ftype = File.stat(target_path).ftype

      # sigh, monkey patch instance method for instance, and close over link_ftype
      singleton_class.send(:define_method, :ftype) do
        link_ftype
      end
    end

    singleton_class.send(:define_method, :mode) do
      Puppet::Util::Windows::Security.get_mode(target_path)
    end

    stat
  end
  module_function :stat

  def lstat(file_name)
    file_name = file_name.to_s # accomodate PathName or String
    # monkey'ing around!
    stat = File.lstat(file_name)

    singleton_class = class << stat; self; end
    singleton_class.send(:define_method, :mode) do
      Puppet::Util::Windows::Security.get_mode(file_name)
    end

    if symlink?(file_name)
      def stat.ftype
        "link"
      end
    end
    stat
  end
  module_function :lstat

  private

  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa364571(v=vs.85).aspx
  FSCTL_GET_REPARSE_POINT = 0x900a8

  def self.resolve_symlink(handle)
    path = nil
    get_reparse_point_data(handle) do |reparse_data|
      offset = reparse_data[:PrintNameOffset]
      length = reparse_data[:PrintNameLength]

      ptr = reparse_data.pointer + reparse_data.offset_of(:PathBuffer) + offset
      path = ptr.read_wide_string(length / 2) # length is bytes, need UTF-16 wchars
    end

    path
  end

  ffi_convention :stdcall

  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa365512(v=vs.85).aspx
  # BOOL WINAPI ReplaceFile(
  #   _In_        LPCTSTR lpReplacedFileName,
  #   _In_        LPCTSTR lpReplacementFileName,
  #   _In_opt_    LPCTSTR lpBackupFileName,
  #   _In_        DWORD dwReplaceFlags - 0x1 REPLACEFILE_WRITE_THROUGH,
  #                                      0x2 REPLACEFILE_IGNORE_MERGE_ERRORS,
  #                                      0x4 REPLACEFILE_IGNORE_ACL_ERRORS
  #   _Reserved_  LPVOID lpExclude,
  #   _Reserved_  LPVOID lpReserved
  # );
  ffi_lib :kernel32
  attach_function_private :ReplaceFileW,
    [:lpcwstr, :lpcwstr, :lpcwstr, :dword, :lpvoid, :lpvoid], :win32_bool

  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa365240(v=vs.85).aspx
  # BOOL WINAPI MoveFileEx(
  #   _In_      LPCTSTR lpExistingFileName,
  #   _In_opt_  LPCTSTR lpNewFileName,
  #   _In_      DWORD dwFlags
  # );
  ffi_lib :kernel32
  attach_function_private :MoveFileExW,
    [:lpcwstr, :lpcwstr, :dword], :win32_bool

  # BOOLEAN WINAPI CreateSymbolicLink(
  #   _In_  LPTSTR lpSymlinkFileName, - symbolic link to be created
  #   _In_  LPTSTR lpTargetFileName, - name of target for symbolic link
  #   _In_  DWORD dwFlags - 0x0 target is a file, 0x1 target is a directory
  # );
  # rescue on Windows < 6.0 so that code doesn't explode
  begin
    ffi_lib :kernel32
    attach_function_private :CreateSymbolicLinkW,
      [:lpwstr, :lpwstr, :dword], :win32_bool
  rescue LoadError
  end

  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa364944(v=vs.85).aspx
  # DWORD WINAPI GetFileAttributes(
  #   _In_  LPCTSTR lpFileName
  # );
  ffi_lib :kernel32
  attach_function_private :GetFileAttributesW,
    [:lpcwstr], :dword

  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa365535(v=vs.85).aspx
  # BOOL WINAPI SetFileAttributes(
  #   _In_  LPCTSTR lpFileName,
  #   _In_  DWORD dwFileAttributes
  # );
  ffi_lib :kernel32
  attach_function_private :SetFileAttributesW,
    [:lpcwstr, :dword], :win32_bool

  # HANDLE WINAPI CreateFile(
  #   _In_      LPCTSTR lpFileName,
  #   _In_      DWORD dwDesiredAccess,
  #   _In_      DWORD dwShareMode,
  #   _In_opt_  LPSECURITY_ATTRIBUTES lpSecurityAttributes,
  #   _In_      DWORD dwCreationDisposition,
  #   _In_      DWORD dwFlagsAndAttributes,
  #   _In_opt_  HANDLE hTemplateFile
  # );
  ffi_lib :kernel32
  attach_function_private :CreateFileW,
    [:lpcwstr, :dword, :dword, :pointer, :dword, :dword, :handle], :handle

  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa363216(v=vs.85).aspx
  # BOOL WINAPI DeviceIoControl(
  #   _In_         HANDLE hDevice,
  #   _In_         DWORD dwIoControlCode,
  #   _In_opt_     LPVOID lpInBuffer,
  #   _In_         DWORD nInBufferSize,
  #   _Out_opt_    LPVOID lpOutBuffer,
  #   _In_         DWORD nOutBufferSize,
  #   _Out_opt_    LPDWORD lpBytesReturned,
  #   _Inout_opt_  LPOVERLAPPED lpOverlapped
  # );
  ffi_lib :kernel32
  attach_function_private :DeviceIoControl,
    [:handle, :dword, :lpvoid, :dword, :lpvoid, :dword, :lpdword, :pointer], :win32_bool

  MAXIMUM_REPARSE_DATA_BUFFER_SIZE = 16384

  # REPARSE_DATA_BUFFER
  # http://msdn.microsoft.com/en-us/library/cc232006.aspx
  # http://msdn.microsoft.com/en-us/library/windows/hardware/ff552012(v=vs.85).aspx
  # struct is always MAXIMUM_REPARSE_DATA_BUFFER_SIZE bytes
  class REPARSE_DATA_BUFFER < FFI::Struct
    layout :ReparseTag, :win32_ulong,
           :ReparseDataLength, :ushort,
           :Reserved, :ushort,
           :SubstituteNameOffset, :ushort,
           :SubstituteNameLength, :ushort,
           :PrintNameOffset, :ushort,
           :PrintNameLength, :ushort,
           :Flags, :win32_ulong,
           # max less above fields dword / uint 4 bytes, ushort 2 bytes
           # technically a WCHAR buffer, but we care about size in bytes here
           :PathBuffer, [:byte, MAXIMUM_REPARSE_DATA_BUFFER_SIZE - 20]
  end
end
