//
//  BoosterSim.swift
//  Rocketeer
//
//  Created by Tadeas Kriz on 17/01/2017.
//  Copyright © 2017 Brightify. All rights reserved.
//

//: Playground - noun: a place where people can play

import Cocoa

/// J/mol-K
let universalGasConstant = 8314.0
// kg/kmol
let effectiveMolecularWeightOfProducts = 42.39
// J/kg-K
let specificGasConstant = 196.1

// Ratio of specific heats, mixture
let ratioOfSpecificHeats = 1.131

let combustionEfficiency = 0.95

/// Pa Ambient pressure
let Patm = 101_000.0 // 101_325.0
/// Propellant erosive burning velocity coefficient
let kv = 0.0

/// Propellant erosive burning area ratio threshold
let GStar = 6.0

/*let idealCombustionTemperature
 To	1710	K	Ideal combustion temperature
 To act	1625	K	Actual chamber temperature

 c*	889	m/s	Characteristic exhaust velocity
 */
let propellantErosiveBurningAreaRatioThreshold = 0
let propellantErosiveBurningVelocityCoefficient = 0
let π = Double.pi

extension FloatingPoint {
    var degreesToRadians: Self { return self * .pi / 180 }
    var radiansToDegrees: Self { return self * 180 / .pi }
}

postfix operator °

postfix func ° (value: Double) -> Double {
    return value.degreesToRadians
}

protocol Volumetric {
    var volume: Double { get }
}

protocol Cylindrical: Volumetric {
    var length: Double { get }
    var diameter: Double { get }
}

extension Cylindrical {
    var volume: Double {
        return π * pow(diameter / 2, 2) * length
    }

    var wallArea: Double {
        return 2 * π * (diameter / 2) * length
    }

    var faceArea: Double {
        return π * pow(diameter / 2, 2)
    }

    var area: Double {
        return wallArea + 2 * faceArea
    }
}

struct Cylinder: Cylindrical {
    let length: Double
    let diameter: Double
}

enum Fuel: String {
    case knsb
    case knsu
    case kndx
    case kner
    case knmn

    /// Grain mass density, ideal - ρπ [g/cm3]
    var density: Double {
        switch self {
        case .knsb:
            return 1.841
        case .knsu:
            return 1.889
        case .kndx:
            return 1.879
        case .kner:
            return 1.820
        case .knmn:
            return 1.854
        }
    }

    /// Ratio of specific heats, 2-ph. - k2ph
    /// For the dynamic (zero lag) gas-particle mixture.
    var ratioOfSpecificHeats2ph: Double {
        switch self {
        case .knsb:
            return 1.042
        case .knsu:
            return 1.044
        case .kndx:
            return 1.043
        case .kner:
            return 1.043
        case .knmn:
            return 1.042
        }
    }

    /// Ratio of specific heats, mixture - k
    /// For the static gas-particle mixture.
    var ratioOfSpecificHeatsMixture: Double {
        switch self {
        case .knsb:
            return 1.136
        case .knsu:
            return 1.133
        case .kndx:
            return 1.131
        case .kner:
            return 1.139
        case .knmn:
            return 1.136
        }
    }

    /// Effective molecular weight - M [kg/mol]
    /// Given by system mass divided by number of gas moles in system.
    var effectiveMolecularWeight: Double {
        switch self {
        case .knsb:
            return 39.90
        case .knsu:
            return 41.98
        case .kndx:
            return 42.39
        case .kner:
            return 38.78
        case .knmn:
            return 39.83
        }
    }

    /// Chamber temperature - To [K]
    /// Adiabatic flame temperature.
    var chamberTemperature: Double {
        switch self {
        case .knsb:
            return 1600
        case .knsu:
            return 1720
        case .kndx:
            return 1710
        case .kner:
            return 1608
        case .knmn:
            return 1616
        }
    }

    /// a: [Pa], n: [mm/sec]
    func burnRateData(pressure: Double) -> (a: Double, n: Double) {
        switch self {
        case .kndx:
            switch pressure {
            case 0...779_000:
                return (a: 8.875, n: 0.619)
            case 779_000...2_572_000:
                return (a: 7.553, n: -0.009)
            case 2_572_000...5_930_000:
                return (a: 3.841, n: 0.688)
            case 5_930_000...8_502_000:
                return (a: 17.2, n: -0.148)
            case 8_502_000...11_200_000:
                return (a: 4.775, n: 0.422)
            default:
                fatalError("Too high pressure! \(pressure)")
            }

        case .knsu:
            // Valid for pressure 0.101 to 10.300 MPa
            return (a: 8_260_000, n: 0.319) // r = ro + a Pc n
        default: return (1, 1)
        }
    }
}

struct GrainSides: OptionSet {
    static let outer = GrainSides(rawValue: 1 << 0)
    static let core = GrainSides(rawValue: 1 << 1)
    static let ends = GrainSides(rawValue: 1 << 2)
    static let all: GrainSides = [outer, core, ends]

    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

struct Grains {
    let fuel: Fuel

    let inhibitedSides: GrainSides
    /// mm
    let coreDiameter: Double
    /// mm
    let length: Double
    /// mm
    let diameter: Double

    let numberOfGrains: Int

    /// actual / ideal
    let densityRatio = 0.95

    var outerCylinder: Cylinder {
        return Cylinder(length: length, diameter: diameter)
    }

    var coreCylinder: Cylinder {
        return Cylinder(length: length, diameter: coreDiameter)
    }

    var totalLength: Double {
        return length * Double(numberOfGrains)
    }

    var totalVolume: Double {
        return (outerCylinder.volume - coreCylinder.volume) * 4
    }

    /// [g/cm3]
    var actualDensity: Double {
        return densityRatio * fuel.density
    }

    func burnArea(time: Double) -> Double {
        var area = 0.0
        if !inhibitedSides.contains(.outer) {
            area += outerCylinder.wallArea
        }

        if !inhibitedSides.contains(.core) {
            area += coreCylinder.wallArea
        }

        if !inhibitedSides.contains(.ends) {
            area += 2 * (outerCylinder.faceArea - coreCylinder.faceArea)
        }

        return area
    }
}

struct Chamber: Cylindrical {
    // mm
    let length: Double
    /// mm
    let diameter: Double
    let grains: Grains

    func burnArea(time: Double) -> Double {
        return 0
    }
}

struct Nozzle {
    /// mm
    let throatDiameter: Double
    /// radians
    let convergentAngle: Double
    /// radians
    let divergentAngle: Double
    /// mm
    let erosion: Double

    var throatArea: Double {
        return 0.25 * Double.pi * pow(throatDiameter, 2)
    }

}

struct Booster {
    let chamber: Chamber
    let nozzle: Nozzle
}

struct KnSimulation {
    let booster: Booster

    /// mm
    let simulationStep: Double

    /// Grain regression (depth burned) [mm]
    var x = 0.0

    /// Core diameter [mm]
    var d: Double {
        let grains = booster.chamber.grains

        return grains.coreDiameter +
            (grains.inhibitedSides.contains(.core) ? 0 : 2 * x)
    }

    /// Grain outer diameter [mm]
    var D: Double {
        let grains = booster.chamber.grains

        return grains.diameter -
            (grains.inhibitedSides.contains(.outer) ? 0 : 2 * x)
    }

    /// Grain total length [mm]
    var L: Double {
        let grains = booster.chamber.grains

        return grains.totalLength -
            (grains.inhibitedSides.contains(.ends) ? 0 : 2 * Double(grains.numberOfGrains) * x)
    }

    /// Grain web thickness [mm]
    var tweb: Double {
        return (D - d) / 2
    }

    var twebInitial: Double {
        let grains = booster.chamber.grains
        return (grains.diameter - grains.coreDiameter) / 2
    }

    /// Burning area, ends [mm^2]
    var abe: Double {
        let grains = booster.chamber.grains
        guard !grains.inhibitedSides.contains(.ends) else { return 0 }
        return 2 * Double(grains.numberOfGrains) * Double.pi / 4 * (pow(D, 2) - pow(d, 2))
    }

    /// Burning area, core [mm^2]
    var abc: Double {
        let grains = booster.chamber.grains
        guard !grains.inhibitedSides.contains(.core) else { return 0 }
        return Double.pi * d * L
    }

    /// Burning area, surface [mm^2]
    var abs: Double {
        let grains = booster.chamber.grains
        guard !grains.inhibitedSides.contains(.outer) else { return 0 }
        return Double.pi * D * L
    }

    /// Burning area, total [mm^2]
    var abTotal: Double {
        return abe + abc + abs
    }

    /// Throat cross-section area [mm^2]
    var at: Double {
        let nozzle = booster.nozzle
        return Double.pi / 4 * pow(nozzle.throatDiameter + nozzle.erosion * (twebInitial - tweb) / twebInitial, 2)
    }

    /// Ratio of burning area to throat area
    var kn: Double {
        return abTotal / at
    }

    var deltaX: Double {
        return twebInitial - x * (
            (booster.chamber.grains.inhibitedSides.contains(.core) ? 0 : 1) + (booster.chamber.grains.inhibitedSides.contains(.outer) ? 0 : 1)
        )
    }

    init(booster: Booster, simulationStep: Double = 0.49, currentStep: Int = 0) {
        self.booster = booster
        self.simulationStep = simulationStep

        self.x = Double(currentStep) * simulationStep
    }

    mutating func step() {
        x += simulationStep
    }
}

struct PressureSimulation {
    let booster: Booster

    /// mm
    let simulationStep: Double

    var knSimulation: KnSimulation

    /// Web regression [mm]
    var x = 0.0

    /// Time since start of burn [sec]
    var t = 0.0

    var PoLast = Patm

    /// Chamber pressure [Pa] (abs)
    var Po = Patm

    /// Mass generation rate of combustion products [kg/s]
    var mGen: Double = 0.0

    /// Mass flow rate through nozzle [kg/s]
    var mNoz: Double = 0.0

    var massSto: Double = 0.0

    var ai29: Double = 0.0

    /// Nozzle critical passage area [m^2]
    var aStar: Double {
        return knSimulation.at / pow(1000, 2)
    }

    /// Difference in chamber and grain cross-sectional area (flow area) [mm^2]
    var aDuct: Double {
        return Double.pi / 4 * pow(booster.chamber.diameter, 2) - Double.pi / 4 * (pow(knSimulation.D, 2) - pow(knSimulation.d, 2))
    }

    /// Erosive burning factor
    var G: Double {
        return max(0, GStar - (aDuct / knSimulation.at))
    }

    /// a: Burn rate coefficient valid at Po
    /// n: Pressure exponent valid at Po
    var burnRateCoeficients: (a: Double, n: Double) {
        return booster.chamber.grains.fuel.burnRateData(pressure: PoLast)
    }

    /// Propellant burn rate [mm/s]
    var r: Double {
        let coefficients = burnRateCoeficients
        return (1 + kv * G) * coefficients.a * pow(PoLast / 1_000_000, coefficients.n)
    }

    /// [mm^3]
    var grainVolume: Double {
        return Double.pi / 4 * (pow(knSimulation.D, 2) - pow(knSimulation.d, 2)) * knSimulation.L
    }

    /// Free volume in chamber [mm^3]
    var freeVolume: Double {
        return booster.chamber.volume - grainVolume
    }

    /// [kg]
    var grainMass: Double {
        return booster.chamber.grains.actualDensity * grainVolume / 1000_000
    }

    /// Mass storage rate of combustion products (in chamber) [kg/s]
    var mSto: Double {
        return mGen - mNoz
    }

    /// Density of combustion products in chamber [kg/m^3]
    var productsDensityInChamber: Double {
        return massSto / (freeVolume / 1000_000_000)
    }


    /// burst 0 Mpa
    let pBurst = 0.0

    init(booster: Booster, simulationStep: Double = 0.49) {
        self.booster = booster
        self.simulationStep = simulationStep
        self.knSimulation = KnSimulation(booster: booster, simulationStep: simulationStep)
    }

    mutating func step() {
        let previousStep = self
        knSimulation.step()
        x += simulationStep
        PoLast = Po
        t += simulationStep / r
        mGen = (previousStep.grainMass - grainMass) / (t - previousStep.t)

        let actualChamberTemperature = booster.chamber.grains.fuel.chamberTemperature * combustionEfficiency
        ai29 = (PoLast - Patm) * aStar / sqrt(specificGasConstant * actualChamberTemperature) * sqrt(ratioOfSpecificHeats) * pow(2 / (ratioOfSpecificHeats + 1), (ratioOfSpecificHeats + 1) / 2 / (ratioOfSpecificHeats - 1))

        if mGen < ai29 {
            if PoLast > pBurst {
                mNoz = ai29
            } else {
                mNoz = 0
            }
        } else {
            mNoz = ai29
        }
        
        massSto += mSto * (t - previousStep.t)
        
        Po = productsDensityInChamber * specificGasConstant * actualChamberTemperature + Patm
    }
}
