# Basic Data Structrue and Loader for ARPES Data from Beamlines

This project aims to build the basic ARPES data structures and loaders in Matlab, providing elementary data process capabilities. The data types were written in Matlab `class`, intergrating the data and data process operations.

Main Features:
- Load data file `DataLoader/loader_UI.m`
- Basic data process
    - K-space convert
    - Set contrast
    - Truncate
    - Smooth / Second Derivative
    - Normalise
    - Spike removal
- More data analysis
    - Fermi level fitting
    - Energy intensity distribution
    - Symmetrise and interpolate

Data types included:
- Cut / Corelevel `DataType/OxA_CUT.m`
- Map `DataType/OxA_MAP.m`
- Map (by Time-of-Fly) `DataType/OxA_MAP_ToF.m`
- Photon energy scan (Kz) `DataType/OxA_KZ.m`
- Real space scan `DataType/OxA_RSImage.m`
- Corelevel / EDC `DataType/OxArpes_1D_Data.m`

Supported Beamlines:
- Beamlines with Scienta Omicron Analyser 
    - using SES software `DataLoader/load_scienta_txt.m`, `DataLoader/load_scienta_zip.m`, `DataLoader/load_scienta_IBW.m`
    - using PEAK software `DataLoader/load_scienta_IBW.m`
- Diamond Light Source 
    - i05 `DataLoader/load_DLS_io5.m`
    - i09 `DataLoader/load_DLS_io9_HAXPES.m`, `load_DLS_io9_kPEEM.m`
- Swiss Light Source 
    - ULTRA `DataLoader/load_PSI_ULTRA.m`
    - ADRESS (testing)
- Elettra Spectromicroscopy `DataLoader/load_Elettra_Spectromicroscopy.m`
- Soleil Cassiopee .txt `DataLoader/test/load_Soleil_Cassiopee_folder.m`
- ALBA Lorea (HR & spin) .nxs/.krx `DataLoader/load_ALBA_LOREA.m`, `DataLoader/load_ALBA_krx.m`, `DataLoader/load_ALBA_krx_S.m`,
- ALS BL10 & BL7 MAESTRO .fits `DataLoader/load_ALS_Maestro_fits.m`
- SSRL BL5-2 `DataLoader/load_SSRL_BL52.m`

Other Tools:
- 2D/3D data viewer `OxArpes_DataViewer_2D.mlapp`, `OxArpes_DataViewer_3D.mlapp`
- Resolution calculator `OxArpes_ResolutionCalculator.mlapp`
- Basic data process panel `OxArpes_DataProcess.mlapp`
- Fine structure viewer `OxArpes_FineStructure.mlapp`
- Data normlaise `OxArpes_Normalise.mlapp`
- Data auto sync `OxArpes_Sync.mlapp`
- Data list browser `OxArpes_DataList.mlapp`

Usage / Getting Started:
- This package is being updated periodically as needed
- It is meant to be become a back-end component of the early ARPES data process software `yulinARPES`.


---
Contact: Cheng Peng <cheng.peng@physics.ox.ac.uk>

Group web: [Chen Group | ARPES at Oxford](http://www.arpes.org.uk)

