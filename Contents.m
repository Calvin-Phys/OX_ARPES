% OX_ARPES
% Version: development
%
% Data loading
%   load_arpes  - Load a supported ARPES file without UI/workspace effects.
%   loader_UI   - Interactive loader and base-workspace compatibility entry.
%
% Core data types
%   OxArpes_1D_Data - One-dimensional axis/value container.
%   OxArpes_2D_Data - Two-dimensional axis/value container.
%   OxArpes_3D_Data - Three-dimensional axis/value container.
%   OxArpes_4D_Data - Four-dimensional value(x,y,k,z) container.
%   OxA_CUT          - ARPES analyser-angle/energy cut.
%   OxA_MAP          - Two-angle/energy ARPES map.
%   OxA_MAP_ToF      - Time-of-flight ARPES map.
%   OxA_KZ           - Photon-energy/angle/energy scan.
%   OxA_RSImage      - Real-space/energy scan.
%
% Selected analysis
%   fit_fermi_edge_ox                    - Fit a Fermi edge.
%   fdd_fit_edc                          - Toolbox-free Fermi-edge fit (FDD).
%   fdd_correct_data                     - E_F shift / Fermi-Dirac division on a copy.
%   ox_calibrate_fermi_kz_scan           - Estimate and correct EF drift.
%   ox_energy_intensity_distribution     - Estimate EID backgrounds.
%   ox_remove_background                 - Subtract an EID background.
%   sym_map_data_autoMask                - C3/mirror map symmetrisation.
%   PCA_cluster                          - PCA plus k-means clustering.
%   custom_fcm                           - Fuzzy c-means clustering.
%   h_cluster                            - Hierarchical clustering.
%
% Apps
%   OxArpes_DataProcess - Crop/smooth/normalise/reduce workspace data.
%   FDD_fit_app         - Fermi-edge fitting and Fermi-Dirac correction (GUI/FDD).
%
% Run synthetic regression tests with tests/run_tests.
