import Foundation

public struct Chip {
    public enum ChipType: UInt32 {
        case small = 1
        case medium
        case big
    }
    
    public let chipType: ChipType
    
    public static func make() -> Chip {
        guard let chipType = Chip.ChipType(rawValue: UInt32(arc4random_uniform(3) + 1)) else {
            fatalError("Incorrect random value")
        }
        
        return Chip(chipType: chipType)
    }
    
    public func sodering() {
        let soderingTime = chipType.rawValue
        sleep(UInt32(soderingTime))
    }
}

public class ChipStorage: ObservableObject {
    private var idxPUSH = 0
    private var idxPOP = 0
    static var isEmpty = false
    var stack = [Chip]()
    let syncQueue = DispatchQueue(label: "stack", qos: .utility, attributes: .concurrent)
    
    public func push(elementChip: Chip) {
        self.idxPUSH += 1
        self.syncQueue.async(flags: .barrier) {
            print("--------- Добавился \(self.idxPUSH)й элемент ---------")
            print("   размер стека до добавления: \(self.stack.count)")
            self.stack.append(Chip.make())
            print("размер стека после добавления: \(self.stack.count)")
            print("-------------------------------------------------------\n")
        }
    }
    
    public func pop() -> Chip {
        var lastElement = Chip.make()
        self.idxPOP += 1
        self.syncQueue.async(flags: .barrier) {
            print("---------- Удалился \(self.idxPOP)й элемент ----------")
            print("     размер стека до удаления: \(self.stack.count)")
            lastElement = self.stack.popLast()!
            print("  размер стека после удаления: \(self.stack.count)")
            print("-------------------------------------------------------\n")
        }
        
        return lastElement
    }
}

var storage = ChipStorage()

class GenerationThread: Thread {
    
    private var timer = Timer()
    private var time = Int()
    private let mainTime: Int
    private let timeInterval: Int
    
    init(mainTime: Int, timeInterval: Int) {
        self.mainTime = mainTime
        self.timeInterval = timeInterval
    }
    
    override func main () {
        self.timer = Timer(timeInterval: Double(self.timeInterval),
                           target: self,
                           selector: #selector(updateTimer),
                           userInfo: nil,
                           repeats: true)
        
        RunLoop.current.add(self.timer, forMode: .common)
        RunLoop.current.run()
        
        if Thread.current.isCancelled {
            return
        }
    }
    
    @objc func updateTimer() {
        time += timeInterval
        print("ВРЕМЯ - \(time)\n")
        storage.push(elementChip: Chip.make())
        
        if time >= mainTime {
            timer.invalidate()
        }
    }
}

class WorkThread: Thread {
    override func main() {
        while !Thread.current.isCancelled {
            if storage.stack.last != nil {
                let lastElemenet = storage.pop()
                lastElemenet.sodering()
            }
        }
    }
}

let generationThread = GenerationThread(mainTime: 20, timeInterval: 2)
let workThread = WorkThread()

generationThread.start()
workThread.start()

DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
    generationThread.cancel()
    print("\n----- ПОТОК GenerationThread остановлен -----\n")
}

DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
    if generationThread.isCancelled && storage.stack.count == 0 {
        workThread.isCancelled
    }
    print("\n----- ПОТОК WorkThread остановлен -----------")
}

