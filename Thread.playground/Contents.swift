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
        print("sleep - \(UInt32(soderingTime))")
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
        print("\(self.idxPUSH) -> before PUSH: \(stack.count)")
        self.syncQueue.async(flags: .barrier) { [weak self] in
            self?.stack.append(Chip.make())
            print("\(self!.idxPUSH) -> after PUSH: \(self?.stack.count)")
        }
    }
    
    public func pop() -> Chip {
        var lastElement = Chip.make()
        self.idxPOP += 1
        print("\(self.idxPOP) -> before POP: \(stack.count)")
        self.syncQueue.async(flags: .barrier) {
            lastElement = self.stack.popLast()!
            print("\(self.idxPOP) -> after POP: \(self.stack.count)")
        }
        
        return lastElement
    }
}

var storage = ChipStorage()

class GenerationThread: Thread {
    var timer = Timer()
    var time = 0
    let mainTime = 20
    
    override func main () {
        self.timer = Timer(timeInterval: Double(2.0),
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
        time += 2
        storage.push(elementChip: Chip.make())
        print("time = \(time)")
        
        if time == mainTime {
            timer.invalidate()
        }
    }
}
let generationThread = GenerationThread()

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
let workThread = WorkThread()

generationThread.start()
workThread.start()

DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
    generationThread.cancel()
    print("----- GenerationThread isCancelled -----")
}

DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
    if generationThread.isCancelled && storage.stack.count == 0 {
        workThread.isCancelled
    }
    print("----- WorkThread isCancelled -----")
}

