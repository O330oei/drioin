// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;

using Microsoft.Win32;
using Microsoft.Win32.SafeHandles;

namespace System.Management.Automation
{
    /// <summary>
    /// These are platform abstractions and platform specific implementations.
    /// </summary>
    public static class Platform
    {
        private static string _tempDirectory = null;

        /// <summary>
        /// True if the current platform is Linux.
        /// </summary>
        public static bool IsLinux
        {
            get
            {
                return RuntimeInformation.IsOSPlatform(OSPlatform.Linux);
            }
        }

        /// <summary>
        /// True if the current platform is macOS.
        /// </summary>
        public static bool IsMacOS
        {
            get
            {
                return RuntimeInformation.IsOSPlatform(OSPlatform.OSX);
            }
        }

        /// <summary>
        /// True if the current platform is Windows.
        /// </summary>
        public static bool IsWindows
        {
            get
            {
                return RuntimeInformation.IsOSPlatform(OSPlatform.Windows);
            }
        }

        /// <summary>
        /// True if PowerShell was built targeting .NET Core.
        /// </summary>
        public static bool IsCoreCLR
        {
            get
            {
                return true;
            }
        }

        /// <summary>
        /// True if the underlying system is NanoServer.
        /// </summary>
        public static bool IsNanoServer
        {
            get
            {
#if UNIX
                return false;
#else
                if (_isNanoServer.HasValue) { return _isNanoServer.Value; }

                _isNanoServer = false;
                using (RegistryKey regKey = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Server\ServerLevels"))
                {
                    if (regKey != null)
                    {
                        object value = regKey.GetValue("NanoServer");
                        if (value != null && regKey.GetValueKind("NanoServer") == RegistryValueKind.DWord)
                        {
                            _isNanoServer = (int)value == 1;
                        }
                    }
                }

                return _isNanoServer.Value;
#endif
            }
        }

        /// <summary>
        /// True if the underlying system is IoT.
        /// </summary>
        public static bool IsIoT
        {
            get
            {
#if UNIX
                return false;
#else
                if (_isIoT.HasValue) { return _isIoT.Value; }

                _isIoT = false;
                using (RegistryKey regKey = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion"))
                {
                    if (regKey != null)
                    {
                        object value = regKey.GetValue("ProductName");
                        if (value != null && regKey.GetValueKind("ProductName") == RegistryValueKind.String)
                        {
                            _isIoT = string.Equals("IoTUAP", (string)value, StringComparison.OrdinalIgnoreCase);
                        }
                    }
                }

                return _isIoT.Value;
#endif
            }
        }

        /// <summary>
        /// True if underlying system is Windows Desktop.
        /// </summary>
        public static bool IsWindowsDesktop
        {
            get
            {
#if UNIX
                return false;
#else
                if (_isWindowsDesktop.HasValue) { return _isWindowsDesktop.Value; }

                _isWindowsDesktop = !IsNanoServer && !IsIoT;
                return _isWindowsDesktop.Value;
#endif
            }
        }

#if UNIX
        // Gets the location for cache and config folders.
        internal static readonly string CacheDirectory = Platform.SelectProductNameForDirectory(Platform.XDG_Type.CACHE);
        internal static readonly string ConfigDirectory = Platform.SelectProductNameForDirectory(Platform.XDG_Type.CONFIG);
#else
        // Gets the location for cache and config folders.
        internal static readonly string CacheDirectory = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData) + @"\Microsoft\PowerShell";
        internal static readonly string ConfigDirectory = Environment.GetFolderPath(Environment.SpecialFolder.Personal) + @"\PowerShell";

        private static bool? _isNanoServer = null;
        private static bool? _isIoT = null;
        private static bool? _isWindowsDesktop = null;
#endif

        // format files
        internal static List<string> FormatFileNames = new List<string>
            {
                "Certificate.format.ps1xml",
                "Diagnostics.format.ps1xml",
                "DotNetTypes.format.ps1xml",
                "Event.format.ps1xml",
                "FileSystem.format.ps1xml",
                "Help.format.ps1xml",
                "HelpV3.format.ps1xml",
                "PowerShellCore.format.ps1xml",
                "PowerShellTrace.format.ps1xml",
                "Registry.format.ps1xml",
                "WSMan.format.ps1xml"
            };

        /// <summary>
        /// Some common environment variables used in PS have different
        /// names in different OS platforms.
        /// </summary>
        internal static class CommonEnvVariableNames
        {
#if UNIX
            internal const string Home = "HOME";
#else
            internal const string Home = "USERPROFILE";
#endif
        }

        /// <summary>
        /// Remove the temporary directory created for the current process.
        /// </summary>
        internal static void RemoveTemporaryDirectory()
        {
            if (_tempDirectory == null)
            {
                return;
            }

            try
            {
                Directory.Delete(_tempDirectory, true);
            }
            catch
            {
                // ignore if there is a failure
            }

            _tempDirectory = null;
        }

        /// <summary>
        /// Get a temporary directory to use for the current process.
        /// </summary>
        internal static string GetTemporaryDirectory()
        {
            if (_tempDirectory != null)
            {
                return _tempDirectory;
            }

            _tempDirectory = PsUtils.GetTemporaryDirectory();
            return _tempDirectory;
        }

#if UNIX
        /// <summary>
        /// X Desktop Group configuration type enum.
        /// </summary>
        public enum XDG_Type
        {
            /// <summary> XDG_CONFIG_HOME/powershell </summary>
            CONFIG,
            /// <summary> XDG_CACHE_HOME/powershell </summary>
            CACHE,
            /// <summary> XDG_DATA_HOME/powershell </summary>
            DATA,
            /// <summary> XDG_DATA_HOME/powershell/Modules </summary>
            USER_MODULES,
            /// <summary> /usr/local/share/powershell/Modules </summary>
            SHARED_MODULES,
            /// <summary> XDG_CONFIG_HOME/powershell </summary>
            DEFAULT
        }

        /// <summary>
        /// Function for choosing directory location of PowerShell for profile loading.
        /// </summary>
        public static string SelectProductNameForDirectory(Platform.XDG_Type dirpath)
        {
            // TODO: XDG_DATA_DIRS implementation as per GitHub issue #1060

            string xdgconfighome = System.Environment.GetEnvironmentVariable("XDG_CONFIG_HOME");
            string xdgdatahome = System.Environment.GetEnvironmentVariable("XDG_DATA_HOME");
            string xdgcachehome = System.Environment.GetEnvironmentVariable("XDG_CACHE_HOME");
            string envHome = System.Environment.GetEnvironmentVariable(CommonEnvVariableNames.Home);
            if (envHome == null)
            {
                envHome = GetTemporaryDirectory();
            }

            string xdgConfigHomeDefault = Path.Combine(envHome, ".config", "powershell");
            string xdgDataHomeDefault = Path.Combine(envHome, ".local", "share", "powershell");
            string xdgModuleDefault = Path.Combine(xdgDataHomeDefault, "Modules");
            string xdgCacheDefault = Path.Combine(envHome, ".cache", "powershell");

            switch (dirpath)
            {
                case Platform.XDG_Type.CONFIG:
                    // the user has set XDG_CONFIG_HOME corresponding to profile path
                    if (string.IsNullOrEmpty(xdgconfighome))
                    {
                        // xdg values have not been set
                        return xdgConfigHomeDefault;
                    }

                    else
                    {
                        return Path.Combine(xdgconfighome, "powershell");
                    }

                case Platform.XDG_Type.DATA:
                    // the user has set XDG_DATA_HOME corresponding to module path
                    if (string.IsNullOrEmpty(xdgdatahome))
                    {
                        // create the xdg folder if needed
                        if (!Directory.Exists(xdgDataHomeDefault))
                        {
                            try
                            {
                                Directory.CreateDirectory(xdgDataHomeDefault);
                            }
                            catch (UnauthorizedAccessException)
                            {
                                // service accounts won't have permission to create user folder
                                return GetTemporaryDirectory();
                            }
                        }

                        return xdgDataHomeDefault;
                    }
                    else
                    {
                        return Path.Combine(xdgdatahome, "powershell");
                    }

                case Platform.XDG_Type.USER_MODULES:
                    // the user has set XDG_DATA_HOME corresponding to module path
                    if (string.IsNullOrEmpty(xdgdatahome))
                    {
                        // xdg values have not been set
                        if (!Directory.Exists(xdgModuleDefault)) // module folder not always guaranteed to exist
                        {
                            try
                            {
                                Directory.CreateDirectory(xdgModuleDefault);
                            }
                            catch (UnauthorizedAccessException)
                            {
                                // service accounts won't have permission to create user folder
                                return GetTemporaryDirectory();
                            }
                        }

                        return xdgModuleDefault;
                    }
                    else
                    {
                        return Path.Combine(xdgdatahome, "powershell", "Modules");
                    }

                case Platform.XDG_Type.SHARED_MODULES:
                    return "/usr/local/share/powershell/Modules";

                case Platform.XDG_Type.CACHE:
                    // the user has set XDG_CACHE_HOME
                    if (string.IsNullOrEmpty(xdgcachehome))
                    {
                        // xdg values have not been set
                        if (!Directory.Exists(xdgCacheDefault)) // module folder not always guaranteed to exist
                        {
                            try
                            {
                                Directory.CreateDirectory(xdgCacheDefault);
                            }
                            catch (UnauthorizedAccessException)
                            {
                                // service accounts won't have permission to create user folder
                                return GetTemporaryDirectory();
                            }
                        }

                        return xdgCacheDefault;
                    }
                    else
                    {
                        if (!Directory.Exists(Path.Combine(xdgcachehome, "powershell")))
                        {
                            try
                            {
                                Directory.CreateDirectory(Path.Combine(xdgcachehome, "powershell"));
                            }
                            catch (UnauthorizedAccessException)
                            {
                                // service accounts won't have permission to create user folder
                                return GetTemporaryDirectory();
                            }
                        }

                        return Path.Combine(xdgcachehome, "powershell");
                    }

                case Platform.XDG_Type.DEFAULT:
                    // default for profile location
                    return xdgConfigHomeDefault;

                default:
                    // xdgConfigHomeDefault needs to be created in the edge case that we do not have the folder or it was deleted
                    // This folder is the default in the event of all other failures for data storage
                    if (!Directory.Exists(xdgConfigHomeDefault))
                    {
                        try
                        {
                            Directory.CreateDirectory(xdgConfigHomeDefault);
                        }
                        catch
                        {
                            Console.Error.WriteLine("Failed to create default data directory: " + xdgConfigHomeDefault);
                        }
                    }

                    return xdgConfigHomeDefault;
            }
        }
#endif

        /// <summary>
        /// The code is copied from the .NET implementation.
        /// </summary>
        internal static string GetFolderPath(System.Environment.SpecialFolder folder)
        {
            return InternalGetFolderPath(folder);
        }

        /// <summary>
        /// The API set 'api-ms-win-shell-shellfolders-l1-1-0.dll' was removed from NanoServer, so we cannot depend on 'SHGetFolderPathW'
        /// to get the special folder paths. Instead, we need to rely on the basic environment variables to get the special folder paths.
        /// </summary>
        /// <returns>
        /// The path to the specified system special folder, if that folder physically exists on your computer.
        /// Otherwise, an empty string (string.Empty).
        /// </returns>
        private static string InternalGetFolderPath(System.Environment.SpecialFolder folder)
        {
            string folderPath = null;
#if UNIX
            string envHome = System.Environment.GetEnvironmentVariable(Platform.CommonEnvVariableNames.Home);
            if (envHome == null)
            {
                envHome = Platform.GetTemporaryDirectory();
            }

            switch (folder)
            {
                case System.Environment.SpecialFolder.ProgramFiles:
                    folderPath = "/bin";
                    if (!System.IO.Directory.Exists(folderPath)) { folderPath = null; }

                    break;
                case System.Environment.SpecialFolder.ProgramFilesX86:
                    folderPath = "/usr/bin";
                    if (!System.IO.Directory.Exists(folderPath)) { folderPath = null; }

                    break;
                case System.Environment.SpecialFolder.System:
                case System.Environment.SpecialFolder.SystemX86:
                    folderPath = "/sbin";
                    if (!System.IO.Directory.Exists(folderPath)) { folderPath = null; }

                    break;
                case System.Environment.SpecialFolder.Personal:
                    folderPath = envHome;
                    break;
                case System.Environment.SpecialFolder.LocalApplicationData:
                    folderPath = System.IO.Path.Combine(envHome, ".config");
                    if (!System.IO.Directory.Exists(folderPath))
                    {
                        try
                        {
                            System.IO.Directory.CreateDirectory(folderPath);
                        }
                        catch (UnauthorizedAccessException)
                        {
                            // directory creation may fail if the account doesn't have filesystem permission such as some service accounts
                            folderPath = string.Empty;
                        }
                    }

                    break;
                default:
                    throw new NotSupportedException();
            }
#else
            folderPath = System.Environment.GetFolderPath(folder);
#endif
            return folderPath ?? string.Empty;
        }

        // Platform methods prefixed NonWindows are:
        // - non-windows by the definition of the IsWindows method above
        // - here, because porting to Linux and other operating systems
        //   should not move the original Windows code out of the module
        //   it belongs to, so this way the windows code can remain in it's
        //   original source file and only the non-windows code has been moved
        //   out here
        // - only to be used with the IsWindows feature query, and only if
        //   no other more specific feature query makes sense

        internal static bool NonWindowsIsHardLink(ref IntPtr handle)
        {
            return Unix.IsHardLink(ref handle);
        }

        internal static bool NonWindowsIsHardLink(FileSystemInfo fileInfo)
        {
            return Unix.IsHardLink(fileInfo);
        }

        internal static string NonWindowsInternalGetTarget(string path)
        {
            return Unix.NativeMethods.FollowSymLink(path);
        }

        internal static string NonWindowsGetUserFromPid(int path)
        {
            return Unix.NativeMethods.GetUserFromPid(path);
        }

        internal static string NonWindowsInternalGetLinkType(FileSystemInfo fileInfo)
        {
            if (fileInfo.Attributes.HasFlag(System.IO.FileAttributes.ReparsePoint))
            {
                return "SymbolicLink";
            }

            if (NonWindowsIsHardLink(fileInfo))
            {
                return "HardLink";
            }

            return null;
        }

        internal static bool NonWindowsCreateSymbolicLink(string path, string target)
        {
            // Linux doesn't care if target is a directory or not
            return Unix.NativeMethods.CreateSymLink(path, target) == 0;
        }

        internal static bool NonWindowsCreateHardLink(string path, string strTargetPath)
        {
            return Unix.NativeMethods.CreateHardLink(path, strTargetPath) == 0;
        }

        internal static unsafe bool NonWindowsSetDate(DateTime dateToUse)
        {
            Unix.NativeMethods.UnixTm tm = Unix.NativeMethods.DateTimeToUnixTm(dateToUse);
            return Unix.NativeMethods.SetDate(&tm) == 0;
        }

        internal static bool NonWindowsIsSameFileSystemItem(string pathOne, string pathTwo)
        {
            return Unix.NativeMethods.IsSameFileSystemItem(pathOne, pathTwo);
        }

        internal static bool NonWindowsGetInodeData(string path, out System.ValueTuple<UInt64, UInt64> inodeData)
        {
            UInt64 device = 0UL;
            UInt64 inode = 0UL;
            var result = Unix.NativeMethods.GetInodeData(path, out device, out inode);

            inodeData = (device, inode);
            return result == 0;
        }

        internal static bool NonWindowsIsExecutable(string path)
        {
            return Unix.NativeMethods.IsExecutable(path);
        }

        internal static uint NonWindowsGetThreadId()
        {
            return Unix.NativeMethods.GetCurrentThreadId();
        }

        internal static int NonWindowsGetProcessParentPid(int pid)
        {
            return IsMacOS ? Unix.NativeMethods.GetPPid(pid) : Unix.GetProcFSParentPid(pid);
        }

        // Please note that `Win32Exception(Marshal.GetLastWin32Error())`
        // works *correctly* on Linux in that it creates an exception with
        // the string perror would give you for the last set value of errno.
        // No manual mapping is required. .NET Core maps the Linux errno
        // to a PAL value and calls strerror_r underneath to generate the message.

        /// <summary>Unix specific implementations of required functionality.</summary>
        internal static class Unix
        {
            private static Dictionary<int, string> usernameCache = new Dictionary<int, string>();
            private static Dictionary<int, string> groupnameCache = new Dictionary<int, string>();

            /// <summary>The type of a Unix file system item.</summary>
            public enum ItemType
            {
                /// <summary>The item is a Directory.</summary>
                Directory,

                /// <summary>The item is a File.</summary>
                File,

                /// <summary>The item is a Symbolic Link.</summary>
                SymbolicLink,

                /// <summary>The item is a Block Device.</summary>
                BlockDevice,

                /// <summary>The item is a Character Device.</summary>
                CharacterDevice,

                /// <summary>The item is a Named Pipe.</summary>
                NamedPipe,

                /// <summary>The item is a Socket.</summary>
                Socket,
            }

            /// <summary>The mask to use to retrieve specific mode bits from the mode value in the stat class.</summary>
            public enum StatMask
            {
                /// <summary>The mask to collect the owner mode.</summary>
                OwnerModeMask = 0x1C0,

                /// <summary>The mask to get the owners read bit.</summary>
                OwnerRead = 0x100,

                /// <summary>The mask to get the owners write bit.</summary>
                OwnerWrite = 0x080,

                /// <summary>The mask to get the owners execute bit.</summary>
                OwnerExecute = 0x040,

                /// <summary>The mask to get the group mode.</summary>
                GroupModeMask = 0x038,

                /// <summary>The mask to get the group mode.</summary>
                GroupRead = 0x20,

                /// <summary>The mask to get the group mode.</summary>
                GroupWrite = 0x10,

                /// <summary>The mask to get the group mode.</summary>
                GroupExecute = 0x8,

                /// <summary>The mask to get the "other" mode.</summary>
                OtherModeMask = 0x007,

                /// <summary>The mask to get the "other" read bit.</summary>
                OtherRead = 0x004,

                /// <summary>The mask to get the "other" write bit.</summary>
                OtherWrite = 0x002,

                /// <summary>The mask to get the "other" execute bit.</summary>
                OtherExecute = 0x001,

                /// <summary>The mask to retrieve the sticky bit.</summary>
                SetStickyMask = 0x200,

                /// <summary>The mask to retrieve the setgid bit.</summary>
                SetGidMask = 0x400,

                /// <summary>The mask to retrieve the setuid bit.</summary>
                SetUidMask = 0x800,
            }

            /// <summary>The Common Stat class.</summary>
            public class CommonStat
            {
                /// <summary>The inode of the filesystem item.</summary>
                public long Inode;

                /// <summary>The Mode of the filesystem item.</summary>
                public int Mode;

                /// <summary>The user id of the filesystem item.</summary>
                public int UserId;

                /// <summary>The group id of the filesystem item.</summary>
                public int GroupId;

                /// <summary>The number of hard links for the filesystem item.</summary>
                public int HardlinkCount;

                /// <summary>The size in bytes of the filesystem item.</summary>
                public long Size;

                /// <summary>The last access time of the filesystem item.</summary>
                public DateTime AccessTime;

                /// <summary>The last modified time for the filesystem item.</summary>
                public DateTime ModifiedTime;

                /// <summary>The last time the status changes for the filesystem item.</summary>
                public DateTime StatusChangeTime;

                /// <summary>The block size of the filesystem.</summary>
                public long BlockSize;

                /// <summary>The device id of the filesystem item.</summary>
                public int DeviceId;

                /// <summary>The number of blocks used by the filesystem item.</summary>
                public int NumberOfBlocks;

                /// <summary>The type of the filesystem item.</summary>
                public ItemType ItemType;

                /// <summary>Whether the filesystem item has the setuid bit enabled.</summary>
                public bool IsSetUid;

                /// <summary>Whether the filesystem item has the setgid bit enabled.</summary>
                public bool IsSetGid;

                /// <summary>Whether the filesystem item has the sticky bit enabled. This is only available for directories.</summary>
                public bool IsSticky;

                private const char CanRead = 'r';
                private const char CanWrite = 'w';
                private const char CanExecute = 'x';

                // helper for getting unix mode
                private Dictionary<StatMask, char> modeMap = new Dictionary<StatMask, char>()
                {
                        { StatMask.OwnerRead, CanRead },
                        { StatMask.OwnerWrite, CanWrite },
                        { StatMask.OwnerExecute, CanExecute },
                        { StatMask.GroupRead, CanRead },
                        { StatMask.GroupWrite, CanWrite },
                        { StatMask.GroupExecute, CanExecute },
                        { StatMask.OtherRead, CanRead },
                        { StatMask.OtherWrite, CanWrite },
                        { StatMask.OtherExecute, CanExecute },
                };

                private StatMask[] permissions = new StatMask[]
                {
                    StatMask.OwnerRead,
                    StatMask.OwnerWrite,
                    StatMask.OwnerExecute,
                    StatMask.GroupRead,
                    StatMask.GroupWrite,
                    StatMask.GroupExecute,
                    StatMask.OtherRead,
                    StatMask.OtherWrite,
                    StatMask.OtherExecute
                };

                // The item type and the character representation for the first element in the stat string
                private Dictionary<ItemType, char> itemTypeTable = new Dictionary<ItemType, char>()
                {
                    { ItemType.BlockDevice, 'b' },
                    { ItemType.CharacterDevice, 'c' },
                    { ItemType.Directory, 'd' },
                    { ItemType.File, '-' },
                    { ItemType.NamedPipe, 'p' },
                    { ItemType.Socket, 's' },
                    { ItemType.SymbolicLink, 'l' },
                };

                /// <summary>Convert the mode to a string which is usable in our formatting.</summary>
                /// <returns>The mode converted into a Unix style string similar to the output of ls.</returns>
                public string GetModeString()
                {
                    int offset = 0;
                    char[] modeCharacters = new char[10];
                    modeCharacters[offset++] = itemTypeTable[ItemType];

                    foreach (StatMask permission in permissions)
                    {
                        // determine whether we are setuid, sticky, or the usual rwx.
                        if ((Mode & (int)permission) == (int)permission)
                        {
                            if ((permission == StatMask.OwnerExecute && IsSetUid) || (permission == StatMask.GroupExecute && IsSetGid))
                            {
                                // Check for setuid and add 's'
                                modeCharacters[offset] = 's';
                            }
                            else if (permission == StatMask.OtherExecute && IsSticky && (ItemType == ItemType.Directory))
                            {
                                // Directories are sticky, rather than setuid
                                modeCharacters[offset] = 't';
                            }
                            else
                            {
                                modeCharacters[offset] = modeMap[permission];
                            }
                        }
                        else
                        {
                            modeCharacters[offset] = '-';
                        }

                        offset++;
                    }

                    return new string(modeCharacters);
                }

                /// <summary>
                /// Get the user name. This is used in formatting, but we shouldn't
                /// do the pinvoke this unless we're going to use it.
                /// </summary>
                /// <returns>The user name.</returns>
                public string GetUserName()
                {
                    if (usernameCache.TryGetValue(UserId, out string username))
                    {
                        return username;
                    }

                    // Get and add the user name to the cache so we don't need to 
                    // have a pinvoke for each file.
                    username = NativeMethods.GetPwUid(UserId);
                    usernameCache.Add(UserId, username);

                    return username;
                }

                /// <summary>
                /// Get the group name. This is used in formatting, but we shouldn't
                /// do the pinvoke this unless we're going to use it.
                /// </summary>
                /// <returns>The name of the group.</returns>
                public string GetGroupName()
                {
                    if (groupnameCache.TryGetValue(GroupId, out string groupname))
                    {
                        return groupname;
                    }

                    // Get and add the group name to the cache so we don't need to 
                    // have a pinvoke for each file.
                    groupname = NativeMethods.GetGrGid(GroupId);
                    groupnameCache.Add(GroupId, groupname);

                    return groupname;
                }
            }

            // This is a helper that attempts to map errno into a PowerShell ErrorCategory
            internal static ErrorCategory GetErrorCategory(int errno)
            {
                return (ErrorCategory)Unix.NativeMethods.GetErrorCategory(errno);
            }

            /// <summary>Is this a hardlink.</summary>
            /// <param name="handle">The handle to a file.</param>
            /// <returns>A boolean that represents whether the item is a hardlink.</returns>
            public static bool IsHardLink(ref IntPtr handle)
            {
                // TODO:PSL implement using fstat to query inode refcount to see if it is a hard link
                return false;
            }

            /// <summary>Determine if the item is a hardlink.</summary>
            /// <param name="fs">A FileSystemInfo to check to determine if it is a hardlink.</param>
            /// <returns>A boolean that represents whether the item is a hardlink.</returns>
            public static bool IsHardLink(FileSystemInfo fs)
            {
                if (!fs.Exists || (fs.Attributes & FileAttributes.Directory) == FileAttributes.Directory)
                {
                    return false;
                }

                int count;
                string filePath = fs.FullName;
                int ret = NativeMethods.GetLinkCount(filePath, out count);
                if (ret == 0)
                {
                    return count > 1;
                }

                throw new Win32Exception(Marshal.GetLastWin32Error());
            }

            /// <summary>
            /// Create a managed replica of the native stat structure.
            /// </summary>
            /// <param name="css">The common stat structure from which we copy.</param>
            /// <returns>A managed common stat class instance.</returns>
            private static CommonStat CopyStatStruct(NativeMethods.CommonStatStruct css)
            {
                CommonStat cs = new CommonStat();
                cs.Inode = css.Inode;
                cs.Mode = css.Mode;
                cs.UserId = css.UserId;
                cs.GroupId = css.GroupId;
                cs.HardlinkCount = css.HardlinkCount;
                cs.Size = css.Size;

                // These can sometime throw if we get too large a number back (seen on Raspbian).
                // As a fallback, set the time to UnixEpoch.
                try
                {
                    cs.AccessTime = DateTime.UnixEpoch.AddSeconds(css.AccessTime).ToLocalTime();
                }
                catch
                {
                    cs.AccessTime = DateTime.UnixEpoch.ToLocalTime();
                }

                try
                {
                    cs.ModifiedTime = DateTime.UnixEpoch.AddSeconds(css.ModifiedTime).ToLocalTime();
                }
                catch
                {
                    cs.ModifiedTime = DateTime.UnixEpoch.ToLocalTime();
                }

                try
                {
                    cs.StatusChangeTime = DateTime.UnixEpoch.AddSeconds(css.StatusChangeTime).ToLocalTime();
                }
                catch
                {
                    cs.StatusChangeTime = DateTime.UnixEpoch.ToLocalTime();
                }

                cs.BlockSize = css.BlockSize;
                cs.DeviceId = css.DeviceId;
                cs.NumberOfBlocks = css.NumberOfBlocks;

                if (css.IsDirectory == 1)
                {
                    cs.ItemType = ItemType.Directory;
                }
                else if (css.IsFile == 1)
                {
                    cs.ItemType = ItemType.File;
                }
                else if (css.IsSymbolicLink == 1)
                {
                    cs.ItemType = ItemType.SymbolicLink;
                }
                else if (css.IsBlockDevice == 1)
                {
                    cs.ItemType = ItemType.BlockDevice;
                }
                else if (css.IsCharacterDevice == 1)
                {
                    cs.ItemType = ItemType.CharacterDevice;
                }
                else if (css.IsNamedPipe == 1)
                {
                    cs.ItemType = ItemType.NamedPipe;
                }
                else
                {
                    cs.ItemType = ItemType.Socket;
                }

                cs.IsSetUid = css.IsSetUid == 1;
                cs.IsSetGid = css.IsSetGid == 1;
                cs.IsSticky = css.IsSticky == 1;

                return cs;
            }

            /// <summary>Get the lstat info from a path.</summary>
            /// <param name="path">The path to the lstat information.</param>
            /// <returns>An instance of the CommonStat for the path.</returns>
            public static CommonStat GetLStat(string path)
            {
                NativeMethods.CommonStatStruct css;
                if (NativeMethods.GetCommonLStat(path, out css) == 0)
                {
                    return CopyStatStruct(css);
                }

                throw new Win32Exception(Marshal.GetLastWin32Error());
            }

            /// <summary>Get the stat info from a path.</summary>
            /// <param name="path">The path to the stat information.</param>
            /// <returns>An instance of the CommonStat for the path.</returns>
            public static CommonStat GetStat(string path)
            {
                NativeMethods.CommonStatStruct css;
                if (NativeMethods.GetCommonStat(path, out css) == 0)
                {
                    return CopyStatStruct(css);
                }

                throw new Win32Exception(Marshal.GetLastWin32Error());
            }

            /// <summary>Read the /proc file system for information about the parent.</summary>
            /// <param name="pid">The process id used to get the parent process.</param>
            /// <returns>The process id.</returns>
            public static int GetProcFSParentPid(int pid)
            {
                const int invalidPid = -1;

                // read /proc/<pid>/stat
                // 4th column will contain the ppid, 92 in the example below
                // ex: 93 (bash) S 92 93 2 4294967295 ...
                var path = $"/proc/{pid}/stat";
                try
                {
                    var stat = System.IO.File.ReadAllText(path);
                    var parts = stat.Split(new[] { ' ' }, 5);
                    if (parts.Length < 5)
                    {
                        return invalidPid;
                    }

                    return Int32.Parse(parts[3]);
                }
                catch (Exception)
                {
                    return invalidPid;
                }
            }

            /// <summary>The native methods class.</summary>
            internal static class NativeMethods
            {
                private const string psLib = "libpsl-native";

                // Ansi is a misnomer, it is hardcoded to UTF-8 on Linux and macOS
                // C bools are 1 byte and so must be marshaled as I1

                [DllImport(psLib, CharSet = CharSet.Ansi)]
                internal static extern int GetErrorCategory(int errno);

                [DllImport(psLib)]
                internal static extern int GetPPid(int pid);

                [DllImport(psLib, CharSet = CharSet.Ansi, SetLastError = true)]
                internal static extern int GetLinkCount([MarshalAs(UnmanagedType.LPStr)]string filePath, out int linkCount);

                [DllImport(psLib, CharSet = CharSet.Ansi, SetLastError = true)]
                [return: MarshalAs(UnmanagedType.I1)]
                internal static extern bool IsExecutable([MarshalAs(UnmanagedType.LPStr)]string filePath);

                [DllImport(psLib, CharSet = CharSet.Ansi)]
                internal static extern uint GetCurrentThreadId();

                // This is a struct tm from <time.h>.
                [StructLayout(LayoutKind.Sequential)]
                internal unsafe struct UnixTm
                {
                    /// <summary>Seconds (0-60).</summary>
                    internal int tm_sec;

                    /// <summary>Minutes (0-59).</summary>
                    internal int tm_min;

                    /// <summary>Hours (0-23).</summary>
                    internal int tm_hour;

                    /// <summary>Day of the month (1-31).</summary>
                    internal int tm_mday;

                    /// <summary>Month (0-11).</summary>
                    internal int tm_mon;

                    /// <summary>The year - 1900.</summary>
                    internal int tm_year;

                    /// <summary>Day of the week (0-6, Sunday = 0).</summary>
                    internal int tm_wday;

                    /// <summary>Day in the year (0-365, 1 Jan = 0).</summary>
                    internal int tm_yday;

                    /// <summary>Daylight saving time.</summary>
                    internal int tm_isdst;
                }

                // We need a way to convert a DateTime to a unix date.
                internal static UnixTm DateTimeToUnixTm(DateTime date)
                {
                    UnixTm tm;
                    tm.tm_sec = date.Second;
                    tm.tm_min = date.Minute;
                    tm.tm_hour = date.Hour;
                    tm.tm_mday = date.Day;
                    tm.tm_mon = date.Month - 1; // needs to be 0 indexed
                    tm.tm_year = date.Year - 1900; // years since 1900
                    tm.tm_wday = 0; // this is ignored by mktime
                    tm.tm_yday = 0; // this is also ignored
                    tm.tm_isdst = date.IsDaylightSavingTime() ? 1 : 0;
                    return tm;
                }

                [DllImport(psLib, CharSet = CharSet.Ansi, SetLastError = true)]
                internal static extern unsafe int SetDate(UnixTm* tm);

                [DllImport(psLib, CharSet = CharSet.Ansi, SetLastError = true)]
                internal static extern int CreateSymLink([MarshalAs(UnmanagedType.LPStr)]string filePath,
                                                         [MarshalAs(UnmanagedType.LPStr)]string target);

                [DllImport(psLib, CharSet = CharSet.Ansi, SetLastError = true)]
                internal static extern int CreateHardLink([MarshalAs(UnmanagedType.LPStr)]string filePath,
                                                          [MarshalAs(UnmanagedType.LPStr)]string target);

                [DllImport(psLib, CharSet = CharSet.Ansi, SetLastError = true)]
                [return: MarshalAs(UnmanagedType.LPStr)]
                internal static extern string FollowSymLink([MarshalAs(UnmanagedType.LPStr)]string filePath);

                [DllImport(psLib, CharSet = CharSet.Ansi, SetLastError = true)]
                [return: MarshalAs(UnmanagedType.LPStr)]
                internal static extern string GetUserFromPid(int pid);

                [DllImport(psLib, CharSet = CharSet.Ansi, SetLastError = true)]
                [return: MarshalAs(UnmanagedType.I1)]
                internal static extern bool IsSameFileSystemItem([MarshalAs(UnmanagedType.LPStr)]string filePathOne,
                                                                 [MarshalAs(UnmanagedType.LPStr)]string filePathTwo);

                [DllImport(psLib, CharSet = CharSet.Ansi, SetLastError = true)]
                internal static extern int GetInodeData([MarshalAs(UnmanagedType.LPStr)]string path,
                                                        out UInt64 device, out UInt64 inode);

                /// <summary>
                /// This is a struct from getcommonstat.h in the native library.
                /// It presents each member of the stat structure as the largest type of that member across 
                /// all stat structures on the platforms we support. This allows us to present a common 
                /// stat structure for all our platforms.
                /// </summary>
                [StructLayout(LayoutKind.Sequential)]
                internal struct CommonStatStruct
                {
                    /// <summary>The inode of the filesystem item.</summary>
                    internal long Inode;

                    /// <summary>The mode of the filesystem item.</summary>
                    internal int Mode;

                    /// <summary>The user id of the filesystem item.</summary>
                    internal int UserId;

                    /// <summary>The group id of the filesystem item.</summary>
                    internal int GroupId;

                    /// <summary>The number of hard links to the filesystem item.</summary>
                    internal int HardlinkCount;

                    /// <summary>The size in bytes of the filesystem item.</summary>
                    internal long Size;

                    /// <summary>The time of the last access for the filesystem item.</summary>
                    internal long AccessTime;

                    /// <summary>The time of the last modification for the filesystem item.</summary>
                    internal long ModifiedTime;

                    /// <summary>The time of the last status change for the filesystem item.</summary>
                    internal long StatusChangeTime;

                    /// <summary>The size in bytes of the file system.</summary>
                    internal long BlockSize;

                    /// <summary>The device id for the filesystem item.</summary>
                    internal int DeviceId;

                    /// <summary>The number of filesystem blocks that the filesystem item uses.</summary>
                    internal int NumberOfBlocks;

                    /// <summary>This filesystem item is a directory.</summary>
                    internal int IsDirectory;

                    /// <summary>This filesystem item is a file.</summary>
                    internal int IsFile;

                    /// <summary>This filesystem item is a symbolic link.</summary>
                    internal int IsSymbolicLink;

                    /// <summary>This filesystem item is a block device.</summary>
                    internal int IsBlockDevice;

                    /// <summary>This filesystem item is a character device.</summary>
                    internal int IsCharacterDevice;

                    /// <summary>This filesystem item is a named pipe.</summary>
                    internal int IsNamedPipe;

                    /// <summary>This filesystem item is a socket.</summary>
                    internal int IsSocket;

                    /// <summary>This filesystem item will run as the the owner if executed.</summary>
                    internal int IsSetUid;

                    /// <summary>This filesystem item will run as the the group if executed.</summary>
                    internal int IsSetGid;

                    /// <summary>Whether the sticky bit is set on the filesystem item.</summary>
                    internal int IsSticky;
                }

                [DllImport(psLib, CharSet = CharSet.Ansi, SetLastError = true)]
                internal static extern unsafe int GetCommonLStat(string filePath, [Out] out CommonStatStruct cs);

                [DllImport(psLib, CharSet = CharSet.Ansi, SetLastError = true)]
                internal static extern unsafe int GetCommonStat(string filePath, [Out] out CommonStatStruct cs);

                [DllImport(psLib, CharSet = CharSet.Ansi, SetLastError = true)]
                internal static extern string GetPwUid(int id);

                [DllImport(psLib, CharSet = CharSet.Ansi, SetLastError = true)]
                internal static extern string GetGrGid(int id);
            }
        }
    }
}
