# Granular I/O

**Hardware design, fabrication files, and software for Granular IO.**

[Project website](https://www.axlab.cs.uchicago.edu/projects/granular-io) · [Paper](https://doi.org/10.1145/3830398.3830589)

Granular I/O is a project that aims to explore bidirectional, malleable tangible interaction using clusters of passive magnetic particles. This repository hosts hardware design and fabrication resources, Arduino code, and the software GUI of the prototype.

> **Status:** This repository is being updated. The LAPM fabrication files listed below are included in the current folder structure; complete assembly, wiring, and software setup instructions are not yet provided in this README.

## Repository structure

```text
GranularIO/
├── ArduinoCode/
│   ├── EM/                         # Firmware for the EM platform
│   └── LAPM/                       # Firmware for the LAPM platform
├── GUI/
│   └── GranularIO/                 # Graphical user interface
├── Hardware/
│   ├── EM/                         # EM hardware resources
│   ├── LAPM/                       # LAPM fabrication files (detailed below)
│   │   ├── 1_Rail_Array.stl
│   │   ├── 2_Motor_Hub.stl
│   │   ├── 3_Supporting_Beams/
│   │   │   ├── 3_Supporting_Beam_a.stl
│   │   │   ├── 3_Supporting_Beam_b.stl
│   │   │   ├── 3_Supporting_Beam_c.stl
│   │   │   └── 3_Supporting_Beam_d.stl
│   │   ├── 4_MotherBoard_PCB/
│   │   ├── 5_MotorDriver_PCB/
│   │   ├── 6_Pin/
│   │   │   ├── 6_1_Magnet_Holder.stl
│   │   │   ├── 6_2_Screw_Connector.stl
│   │   │   └── 6_3_Encoder_Cap.stl
│   │   └── PCB Kicad Files/        # Additional KiCad-related files
│   └── Other 3D Print Files/       # Other printable components
├── images/                          # README illustrations
├── LICENSE
└── README.md
```

## LAPM hardware assembly

The LAPM platform contains an array of motor-driven magnetic actuator pins. The numbered callouts below correspond to the files and folders in `Hardware/LAPM/`.

![Annotated LAPM hardware assembly](images/assembly-annotated.png)

*Figure 1. LAPM assembly and its six main component groups.*

### Mechanical components

| No. | File or folder (inside `Hardware/LAPM/`) | Description |
| --- | --- | --- |
| **1** | `1_Rail_Array.stl` | Rail array that guides the sliding motion of the magnets. |
| **2** | `2_Motor_Hub.stl` | Motor-mounting structure. Motors are fastened to the hub with screws; the hub also attaches to the rail array (1) and supporting beams (3). |
| **3** | `3_Supporting_Beams/` | Four separate support beams (`a`, `b`, `c`, `d`) connecting the motor hub (2) to the lower electronics assembly. |
| **4** | `4_MotherBoard_PCB/` | Fabrication files, documentation, and 3D model for the motherboard PCB. |
| **5** | `5_MotorDriver_PCB/` | Fabrication and assembly files for the motor-driver PCB. |
| **6** | `6_Pin/` | 3D-printable components used in an individual actuator pin. |

### Individual actuator pin

![Individual actuator pin CAD rendering](images/actuator-pin.png)

*Figure 2. Individual motor-driven actuator pin.*

The `Hardware/LAPM/6_Pin/` folder includes:

| File | Purpose |
| --- | --- |
| `6_1_Magnet_Holder.stl` | Holds the magnet at the moving end of the actuator. |
| `6_2_Screw_Connector.stl` | Connects the screw-driven mechanism to the moving pin assembly. |
| `6_3_Encoder_Cap.stl` | Cap for the motor encoder assembly. |

### PCB fabrication files

**Motherboard** — `Hardware/LAPM/4_MotherBoard_PCB/`

| File | Contents |
| --- | --- |
| `MotherBoard_Gerber.zip` | Gerber manufacturing package for the motherboard. |
| `MotherBoard_3D_Model.step` | 3D model of the PCB assembly. |
| `MotherBoard_Schematic.pdf` | Circuit schematic. |
| `MotherBoard_PCB_F.pdf` | Front-side PCB drawing. |
| `MotherBoard_PCB_B.pdf` | Back-side PCB drawing. |
| `readme.md` | Additional motherboard-specific documentation. |

**Motor-driver board** — `Hardware/LAPM/5_MotorDriver_PCB/`

| File | Contents |
| --- | --- |
| `MotorDriverGerber.zip` | Gerber manufacturing package for the motor-driver board. |
| `MotorDriver_3D_Model.step` | 3D model of the PCB assembly. |
| `MotorDriver_Schematic.pdf` | Circuit schematic. |
| `MotorDriver_PCB_F.pdf` | Front-side PCB drawing. |
| `MotorDriver_PCB_B.pdf` | Back-side PCB drawing. |
| `MotorDriver_BOM.csv` | Component bill of materials. |
| `MotorDriver_pos.csv` | Component placement/position data. |

A separate `Hardware/LAPM/PCB Kicad Files/` folder is also included for additional PCB design files. See the files in that folder for their supported formats and revisions.

### Complete assembly

![Complete LAPM actuation array](images/assembly-overview.png)

*Figure 3. Assembled LAPM motor array, support frame, and electronics.*

## Fabrication notes

- The `.stl` files are intended for manufacturing the mechanical components, typically by 3D printing. The `.step` files provide 3D PCB models.
- Gerber archives are intended for PCB fabrication; schematic PDFs and front/back drawings are provided for reference. For the motor-driver PCB, a BOM and placement file are also included.
- Motors, magnets, screws, and other purchased components are not part of the printable STL files.
- The files are provided as design and fabrication resources, **not** as a complete tested assembly guide. Check dimensions, interfaces, manufacturing requirements, and file revisions before ordering parts.

## Publication

Chi Wang, Clara Cui, Alan Pham, Justice T Andersen, Tucker Rae-Grant, and Ken Nakagaki. **Granular I/O: Enabling Bi-directional Malleable Interaction for Actuated TUIs with Magnetic Particles.** *ACM Symposium on User Interface Software and Technology (UIST 2026).* [DOI: 10.1145/3830398.3830589](https://doi.org/10.1145/3830398.3830589).

## License

See the [LICENSE](LICENSE) file for usage and redistribution terms.
