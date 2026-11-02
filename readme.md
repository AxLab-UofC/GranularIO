# Granular I/O

**Hardware design, fabrication files, and software for Granular IO.**

[Project Website](https://www.axlab.cs.uchicago.edu/projects/granular-io) | [Paper](https://doi.org/10.1145/3830398.3830589)

Granular I/O is a research platform for bidirectional, malleable tangible interaction using clusters of passive magnetic particles. The project explores interactions such as shaping, splitting, and merging magnetic particle clusters through external actuation. This repository hosts hardware design and fabrication resources, Arduino code, and the graphical user interface for the project's two actuation platforms.

> **Repository status:** Work in progress. Some fabrication files and documentation are still being prepared. The presence of source files does not necessarily mean that a complete, tested build procedure is available.

## Repository structure

```text
ArduinoCode/
├── EM/                         # Arduino code for the EM platform
└── LAPM/                       # Arduino code for the LAPM platform
GUI/
└── GranularIO/                 # Graphical user interface
Hardware/
├── EM/                         # EM platform hardware files
├── LAPM/                       # LAPM platform hardware files
│   ├── 4_MotherBoard_PCB/      # Motherboard PCB files
│   └── 5_MotorDriverBoard_PCB/ # Motor-driver PCB files
└── Other 3D Print Files/       # Additional printable parts
LICENSE                         # License terms
README.md                       # This document
```

## LAPM hardware assembly

The LAPM platform uses an array of individually driven magnetic actuators. The renderings below illustrate the mechanical structure, motor mounting, supporting frame, electronics, and individual pin assembly.

![LAPM assembly with numbered component callouts](images/assembly-annotated.png)

*Figure 1. Annotated LAPM assembly. Callout numbers correspond to the component descriptions below.*

### Components and fabrication files

| No. | Component / intended file location | Description | Availability |
| --- | --- | --- | --- |
| **1** | `1_Rails.stl` | Rail array that guides the sliding magnets. | To be added |
| **2** | `2_Motor_Hub.stl` | Housing that secures the motors with screws. It also attaches to the rail array (1) and supporting beams (3). | To be added |
| **3** | `3_Supporting_Beam_a.stl` through `3_Supporting_Beam_d.stl` | Four beams connecting the motor hub (2) to the motherboard PCB assembly (4). | To be added |
| **4** | `Hardware/LAPM/4_MotherBoard_PCB/` | PCB design and fabrication files for the motherboard. | Listed in repository |
| **5** | `Hardware/LAPM/5_MotorDriverBoard_PCB/` | PCB design and fabrication files for the motor-driver boards. | Listed in repository |
| **6** | `6_Pin/` | Parts used to fabricate an individual motor-driven magnetic pin. See below. | To be added |

*Availability reflects the current folder listing; the final locations of the pending STL files may change.*

### Individual actuator pin

![CAD rendering of an individual actuator pin](images/actuator-pin.png)

*Figure 2. Individual actuator pin assembly.*

The planned `6_Pin/` package includes:

| File | Description |
| --- | --- |
| `6_1_Magnet_Holder.stl` | Holds the magnet at the moving end of the pin. |
| `6_2_Screw_Connector.stl` | Connects the lead-screw mechanism to the moving pin assembly. |
| `6_3_Encoder_Cap.stl` | Cap for the motor's encoder assembly. |

### Complete LAPM assembly

![CAD overview of the complete LAPM platform](images/assembly-overview.png)

*Figure 3. Complete LAPM actuation array, including the motorized pins, support structure, and electronics.*

## Fabrication notes

- STL files describe the 3D-printable parts; PCB folders contain board design and/or fabrication resources.
- Motors, magnets, fasteners, and other off-the-shelf components are not included in the printable files.
- Complete assembly instructions, component specifications, and software setup instructions are not yet provided here.
- Check file availability and revision history before manufacturing or ordering PCBs.

## Publication

**Granular I/O: Enabling Bi-directional Malleable Interaction for Actuated TUIs with Magnetic Particles**  
Chi Wang, Clara Cui, Alan Pham, Justice T Andersen, Tucker Rae-Grant, and Ken Nakagaki.  
*ACM Symposium on User Interface Software and Technology (UIST), 2026.*  
https://doi.org/10.1145/3830398.3830589
