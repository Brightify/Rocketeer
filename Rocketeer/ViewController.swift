//
//  ViewController.swift
//  Rocketeer
//
//  Created by Tadeas Kriz on 14/11/2016.
//  Copyright © 2016 Brightify. All rights reserved.
//

import Cocoa
import Charts
import SwiftyUserDefaults

class ViewController: NSViewController {
    @IBOutlet weak var fuelSelection: NSPopUpButton!
    @IBOutlet weak var outerInhibition: NSButton!
    @IBOutlet weak var endsInhibition: NSButton!
    @IBOutlet weak var coreInhibition: NSButton!
    @IBOutlet weak var grainsCoreDiameter: NSTextField!
    @IBOutlet weak var grainLength: NSTextField!
    @IBOutlet weak var grainDiameter: NSTextField!
    @IBOutlet weak var numberOfGrains: NSTextField!
    @IBOutlet weak var chamberLength: NSTextField!
    @IBOutlet weak var chamberDiameter: NSTextField!
    @IBOutlet weak var nozzleThroatDiameter: NSTextField!
    @IBOutlet weak var nozzleConvergentAngle: NSTextField!
    @IBOutlet weak var nozzleDivergentAngle: NSTextField!
    @IBOutlet weak var nozzleErosion: NSTextField!

    @IBOutlet weak var chart1: LineChartView!

    override func viewDidLoad() {
        super.viewDidLoad()

        loadConfig()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func compute(_ sender: Any) {
        func calculate(booster: Booster) {
            var pressureSimulation = PressureSimulation(booster: booster, simulationStep: 0.0294)

            let pressureSimulationSteps = [pressureSimulation] + (1...833).map { _ -> PressureSimulation in
                pressureSimulation.step()
                return pressureSimulation
            }

            func plot(_ arrayToPlot: [Double], title: String) -> LineChartDataSet {
                return LineChartDataSet(values: arrayToPlot.enumerated().map { ChartDataEntry(x: Double($0) * pressureSimulation.simulationStep, y: $1) }, label: title)
            }

            chart1.data = LineChartData(dataSets: [
                plot(pressureSimulationSteps.map { $0.Po }, title: "Po"),
//                plot(pressureSimulationSteps.map { $0.mGen }, title: "mGen"),
//                plot(pressureSimulationSteps.map { $0.mNoz }, title: "mNoz")
                ])


            /*    let header = "xi,tweb,d,D,L,At,A*,Aduct,Aduct/At,G,PoLast,a,n,r,t,Vgrain,Vfree,mgrain,mgen,mnoz,msto,masssto,roprod,Po,ai29"
             let text = pressureSimulationSteps.map { sim -> String in
             let knSim = sim.knSimulation
             return "\(sim.x),\(knSim.tweb),\(knSim.d),\(knSim.D),\(knSim.L),\(knSim.at),\(sim.aStar),\(sim.aDuct),\(sim.aDuct/knSim.at),\(sim.G),\(sim.PoLast),\(sim.burnRateCoeficients.a),\(sim.burnRateCoeficients.n),\(sim.r),\(sim.t),\(sim.grainVolume),\(sim.freeVolume),\(sim.grainMass),\(sim.mGen),\(sim.mNoz),\(sim.mSto),\(sim.massSto),\(sim.productsDensityInChamber),\(sim.Po),\(sim.ai29)"
             }.joined(separator: "\n")
             let file = "results.csv"
             if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
             let path = dir.appendingPathComponent(file)
             //try! (header + "\n" + text).write(to: path, atomically: false, encoding: String.Encoding.utf8)
             }*/

//            var simulation = BoosterSimulation(booster: booster)

//            repeat {
//                simulation.step()
//            } while simulation.remainingFuel > 0.000
        }

        let fuel: Fuel
        switch fuelSelection.selectedItem?.title {
        case "KNSB"?:
            fuel = .knsb
        case "KNSU"?:
            fuel = .knsu
        case "KNDX"?:
            fuel = .kndx
        case "KNER"?:
            fuel = .kner
        case "KNMN"?:
            fuel = .knmn
        default:
            return
        }

        var inhibitedSides: GrainSides = []
        if outerInhibition.state == NSOnState {
            inhibitedSides.insert(GrainSides.outer)
        }
        if endsInhibition.state == NSOnState {
            inhibitedSides.insert(GrainSides.ends)
        }
        if coreInhibition.state == NSOnState {
            inhibitedSides.insert(GrainSides.core)
        }

        let grains = Grains(
            fuel: fuel,
            inhibitedSides: inhibitedSides,
            coreDiameter: grainsCoreDiameter.doubleValue,
            length: grainLength.doubleValue,
            diameter: grainDiameter.doubleValue,
            numberOfGrains: numberOfGrains.integerValue)

        let chamber = Chamber(
            length: chamberLength.doubleValue,
            diameter: chamberDiameter.doubleValue,
            grains: grains)
        
        let nozzle = Nozzle(
            throatDiameter: nozzleThroatDiameter.doubleValue,
            convergentAngle: nozzleConvergentAngle.doubleValue°,
            divergentAngle: nozzleDivergentAngle.doubleValue°,
            erosion: nozzleErosion.doubleValue)
        
        let booster = Booster(
            chamber: chamber,
            nozzle: nozzle)


        saveConfig(booster: booster)
        
        calculate(booster: booster)
    }

    private func saveConfig(booster: Booster) {
        Defaults[.fuel] = booster.chamber.grains.fuel
        Defaults[.inhibitedSides] = booster.chamber.grains.inhibitedSides
        Defaults[.grainsCoreDiameter] = booster.chamber.grains.coreDiameter
        Defaults[.grainLength] = booster.chamber.grains.length
        Defaults[.grainDiameter] = booster.chamber.grains.diameter
        Defaults[.numberOfGrains] = booster.chamber.grains.numberOfGrains
        Defaults[.chamberLength] = booster.chamber.length
        Defaults[.chamberDiameter] = booster.chamber.diameter
        Defaults[.nozzleThroatDiameter] = booster.nozzle.throatDiameter
        Defaults[.nozzleConvergentAngle] = booster.nozzle.convergentAngle
        Defaults[.nozzleDivergentAngle] = booster.nozzle.divergentAngle
        Defaults[.nozzleErosion] = booster.nozzle.erosion
    }

    private func loadConfig() {
        let savedFuel = Defaults[.fuel]
        if let savedSelection = fuelSelection.itemArray.first(where: { $0.title.lowercased() == savedFuel.rawValue.lowercased() }) {
            fuelSelection.select(savedSelection)
        }
        let inhibitedSides = Defaults[.inhibitedSides]
        outerInhibition.state = inhibitedSides.contains(.outer) ? NSOnState : NSOffState
        endsInhibition.state = inhibitedSides.contains(.ends) ? NSOnState : NSOffState
        coreInhibition.state = inhibitedSides.contains(.core) ? NSOnState : NSOffState
        grainsCoreDiameter.doubleValue = Defaults[.grainsCoreDiameter]
        grainLength.doubleValue = Defaults[.grainLength]
        grainDiameter.doubleValue = Defaults[.grainDiameter]
        numberOfGrains.integerValue = Defaults[.numberOfGrains]
        chamberLength.doubleValue = Defaults[.chamberLength]
        chamberDiameter.doubleValue = Defaults[.chamberDiameter]
        nozzleThroatDiameter.doubleValue = Defaults[.nozzleThroatDiameter]
        nozzleConvergentAngle.doubleValue = Defaults[.nozzleConvergentAngle].radiansToDegrees
        nozzleDivergentAngle.doubleValue = Defaults[.nozzleDivergentAngle].radiansToDegrees
        nozzleErosion.doubleValue = Defaults[.nozzleErosion]
    }
}

extension DefaultsKeys {
    static let fuel = DefaultsKey<Fuel>("fuel")
    static let inhibitedSides = DefaultsKey<GrainSides>("inhibitedSides")
    static let grainsCoreDiameter = DefaultsKey<Double>("grainsCoreDiameter")
    static let grainLength = DefaultsKey<Double>("grainLength")
    static let grainDiameter = DefaultsKey<Double>("grainDiameter")
    static let numberOfGrains = DefaultsKey<Int>("numberOfGrains")
    static let chamberLength = DefaultsKey<Double>("chamberLength")
    static let chamberDiameter = DefaultsKey<Double>("chamberDiameter")
    static let nozzleThroatDiameter = DefaultsKey<Double>("nozzleThroatDiameter")
    static let nozzleConvergentAngle = DefaultsKey<Double>("nozzleConvergentAngle")
    static let nozzleDivergentAngle = DefaultsKey<Double>("nozzleDivergentAngle")
    static let nozzleErosion = DefaultsKey<Double>("nozzleErosion")
}

extension UserDefaults {
    subscript(key: DefaultsKey<Fuel>) -> Fuel {
        get { return unarchive(key) ?? Fuel.knsu }
        set { archive(key, newValue) }
    }

    subscript(key: DefaultsKey<GrainSides>) -> GrainSides {
        get { return unarchive(key) ?? GrainSides.outer }
        set { archive(key, newValue) }
    }
}




