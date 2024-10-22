# CharacterNameGenerator.gd
class_name CharacterNameGenerator
extends RefCounted

const FIRST_NAMES = [
	"John", "Jane", "Alex", "Sarah", "Michael", "Emily", "Zorg", "Xyla", "Krath",
	"Ivan", "Chris", "Bill", "Jason", "K'Erin", "Swift", "Precursor", "Soulless",
	"Converted", "Krorg", "Unity", "Skulker", "Krag"
]

const LAST_NAMES = [
	"Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "X'tor",
	"Sorensen", "Modiphius", "Weasel", "Nordic", "Fringe", "Core", "Parsec", "Starport",
	"Galactic", "War", "Swarm", "Hunt", "Bug"
]

const EXTRA_FIRST_NAMES = [
	"Zax", "Vex", "Quark", "Nyx", "Lyra", "Kael", "Jett", "Io", "Hux", "Grix",
	"Faye", "Elix", "Dax", "Cygnus", "Brix", "Astra", "Zephyr", "Vox", "Ulix", "Tarn",
	"Sylar", "Ryx", "Pax", "Orion", "Nova", "Mox", "Lux", "Kix", "Jax", "Helix",
	"Flux", "Eris", "Drax", "Crux", "Blaze", "Axel", "Zara", "Vega", "Tycho", "Seren",
	"Raven", "Psi", "Onyx", "Neon", "Mira", "Luna", "Kyra", "Juno", "Hydra", "Gaia",
	"Fern", "Echo", "Delphi", "Cleo", "Bree", "Arden", "Zion", "Vinn", "Trix", "Solas",
	"Rook", "Pyxis", "Omega", "Neo", "Mace", "Loki", "Koda", "Jace", "Halo", "Gideon",
	"Fable", "Eos", "Dex", "Caspian", "Blitz", "Aries", "Zeke", "Vex", "Tron", "Siren",
	"Rune", "Phoenix", "Orb", "Nova", "Mars", "Lyric", "Krypton", "Jet", "Helios", "Galileo",
	"Aether", "Boreas", "Ceres", "Deimos", "Eos", "Freya", "Ganymede", "Hera", "Iris", "Janus",
	"Kronos", "Leto", "Minos", "Nox", "Oberon", "Phobos", "Quirinus", "Rhea", "Selene", "Theia",
	"Urania", "Vulcan", "Wyvern", "Xena", "Ymir", "Zeus", "Ares", "Bacchus", "Charon", "Dione",
	"Elara", "Faunus", "Gaea", "Hyperion", "Io", "Jupiter", "Kore", "Luna", "Metis", "Nereid",
	"Oceanus", "Pallas", "Quintus", "Rhea", "Saturn", "Titan", "Umbriel", "Venus", "Wezen", "Xibalba",
	"Yggdrasil", "Zephyrus", "Aether", "Boreas", "Chaos", "Demeter", "Erebus", "Fates", "Gaia", "Helios",
	"Iris", "Janus", "Kratos", "Lethe", "Morpheus", "Nemesis", "Ouranos", "Persephone", "Quantum", "Rhea",
	"Styx", "Thanatos", "Uranus", "Vesta", "Warp", "Xanadu", "Yaldabaoth", "Zion", "Aion", "Brizo",
	"Chronos", "Dolos", "Eris", "Fortuna", "Geras", "Harmonia", "Iapetus", "Jove", "Kratos", "Lachesis",
	"Momus", "Nyx", "Oizys", "Pontus", "Quirinus", "Rhea", "Selene", "Tethys", "Urania", "Vortex",
	"Wormhole", "Xenon", "Ymir", "Zelos", "Aether", "Boreas", "Cosmos", "Dysnomia", "Eunomia", "Fobos"
]

const EXTRA_LAST_NAMES = [
	"Voidborn", "Starforge", "Nebula", "Moonwalker", "Lightspeed", "Kuiper", "Jetstream", "Ionos", "Hyperion", "Gravity",
	"Fusion", "Equinox", "Darkmatter", "Comet", "Blazar", "Astro", "Zenith", "Vortex", "Umbra", "Terraform",
	"Supernova", "Radiant", "Pulsar", "Oort", "Neutron", "Meteor", "Lunar", "Kosmos", "Jupiter", "Interstellar",
	"Helios", "Galactic", "Flux", "Eclipse", "Dyson", "Cosmic", "Blackhole", "Asteroid", "Zephyr", "Voyager",
	"Uranus", "Tachyon", "Stardust", "Redshift", "Quasar", "Plasma", "Orbit", "Nova", "Martian", "Lightyear",
	"Kepler", "Io", "Horizon", "Gamma", "Frontier", "Exoplanet", "Dust", "Cosmonaut", "Blueshift", "Andromeda",
	"Zenon", "Void", "Umbra", "Trinary", "Singularity", "Rift", "Quantum", "Photon", "Omega", "Nebulous",
	"Mercury", "Lodestar", "Kugelblitz", "Jovian", "Infinity", "Helix", "Gravity", "Fusion", "Event", "Dust",
	"Comet", "Binary", "Aurora", "Zodiac", "Warp", "Vega", "Ursa", "Tellar", "Sirius", "Rigel",
	"Aether", "Borealis", "Celestial", "Darkstar", "Ethereal", "Frostfire", "Galaxian", "Hypernova", "Ionosphere", "Jupiterian",
	"Kinetic", "Luminous", "Magnetar", "Neutrino", "Orbiter", "Pulsarian", "Quasarian", "Radionic", "Solarian", "Terran",
	"Ultraviolet", "Voidwalker", "Warpspeed", "Xenosphere", "Yottabyte", "Zettaflare", "Astral", "Betelgeuse", "Cryogenic", "Dimensional",
	"Ecliptic", "Fermion", "Graviton", "Hadron", "Iridium", "Jovian", "Kelvin", "Luminal", "Meson", "Neutronium",
	"Oort", "Planck", "Quark", "Relativistic", "Superluminal", "Tachyonic", "Ultrasonic", "Venusian", "Wormhole", "Xenon",
	"Yocto", "Zepto", "Antimatter", "Baryonic", "Chromosphere", "Deuterium", "Exosphere", "Fermion", "Gravitino", "Hawking",
	"Isotope", "Joule", "Kelvin", "Lepton", "Meson", "Nucleon", "Oscillator", "Proton", "Qubit", "Resonator",
	"Scalar", "Tachyon", "Ultraviolet", "Vacuum", "Wavelength", "X-ray", "Yukawa", "Zeeman", "Albedo", "Boson",
	"Chromatic", "Doppler", "Entropy", "Fermion", "Graviton", "Hadron", "Isotope", "Joule", "Kinetic", "Lepton",
	"Muon", "Neutrino", "Oscillation", "Photon", "Quantum", "Radiation", "Scalar", "Tensor", "Uncertainty", "Vector",
	"Wavefunction", "X-ray", "Yield", "Zeeman", "Absolute", "Bohr", "Coulomb", "Dirac", "Einstein", "Fermi"
]

static func get_random_name() -> String:
	var first_name = FIRST_NAMES[randi() % FIRST_NAMES.size()]
	var last_name = LAST_NAMES[randi() % LAST_NAMES.size()]
	return first_name + " " + last_name

static func get_random_name_for_species(species: GlobalEnums.Species) -> String:
	var first_name: String
	var last_name: String
	
	match species:
		GlobalEnums.Species.HUMAN:
			first_name = EXTRA_FIRST_NAMES[randi() % EXTRA_FIRST_NAMES.size()]
			last_name = EXTRA_LAST_NAMES[randi() % EXTRA_LAST_NAMES.size()]
		GlobalEnums.Species.ENGINEER:
			first_name = "ENG-" + str(randi() % 1000).pad_zeros(3)
			last_name = EXTRA_LAST_NAMES[randi() % EXTRA_LAST_NAMES.size()]
		GlobalEnums.Species.KERIN:
			first_name = "K'" + EXTRA_FIRST_NAMES[randi() % EXTRA_FIRST_NAMES.size()]
			last_name = EXTRA_LAST_NAMES[randi() % EXTRA_LAST_NAMES.size()]
		GlobalEnums.Species.SOULLESS:
			first_name = "SL-" + str(randi() % 1000).pad_zeros(3)
			last_name = ""
		GlobalEnums.Species.PRECURSOR:
			first_name = EXTRA_FIRST_NAMES[randi() % EXTRA_FIRST_NAMES.size()]
			last_name = "Ancient"
		GlobalEnums.Species.FERAL:
			first_name = EXTRA_FIRST_NAMES[randi() % EXTRA_FIRST_NAMES.size()]
			last_name = "Wildborn"
		GlobalEnums.Species.SWIFT:
			first_name = EXTRA_FIRST_NAMES[randi() % EXTRA_FIRST_NAMES.size()]
			last_name = "Quicksilver"
		GlobalEnums.Species.BOT:
			first_name = "BOT-" + str(randi() % 1000).pad_zeros(3)
			last_name = ""
		GlobalEnums.Species.SKULKER:
			first_name = "SK-" + str(randi() % 1000).pad_zeros(3)
			last_name = EXTRA_LAST_NAMES[randi() % EXTRA_LAST_NAMES.size()]
		GlobalEnums.Species.KRAG:
			first_name = "KR-" + str(randi() % 1000).pad_zeros(3)
			last_name = EXTRA_LAST_NAMES[randi() % EXTRA_LAST_NAMES.size()]
		_:
			first_name = EXTRA_FIRST_NAMES[randi() % EXTRA_FIRST_NAMES.size()]
			last_name = EXTRA_LAST_NAMES[randi() % EXTRA_LAST_NAMES.size()]
	
	return (first_name + " " + last_name).strip_edges()
