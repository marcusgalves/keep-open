import Darwin
import Foundation

/// Lists executable names of processes owned by a user, like `pgrep -u $USER`.
enum ProcessScanner {
    static func executableNames(ownedBy uid: uid_t = getuid()) -> Set<String> {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }

        var pids = [pid_t](repeating: 0, count: Int(estimate) * 2)
        let count = pids.withUnsafeMutableBufferPointer { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count * MemoryLayout<pid_t>.stride))
        }
        guard count > 0 else { return [] }

        var names = Set<String>()
        var pathBuffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let infoSize = Int32(MemoryLayout<proc_bsdshortinfo>.size)

        for pid in pids.prefix(Int(count)) where pid > 0 {
            var info = proc_bsdshortinfo()
            guard proc_pidinfo(pid, PROC_PIDT_SHORTBSDINFO, 0, &info, infoSize) == infoSize,
                  info.pbsi_uid == uid else { continue }
            if proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count)) > 0 {
                names.insert((String(cString: pathBuffer) as NSString).lastPathComponent)
            }
        }
        return names
    }
}
