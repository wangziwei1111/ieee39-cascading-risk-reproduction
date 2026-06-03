# Additional Paper Data Needed For Strict Reproduction

To move from diagnostic reproduction to strict numerical reproduction, please continue looking for or ask the authors for the following information.

## Wind-Speed Table 4-6 Operating Point

1. Conventional generator `PG` at each wind speed in Table 4-6.
2. Slack bus or balancing generator policy at each wind speed.
3. Whether wind curtailment is used.
4. Actual absorbed wind power at each wind speed.
5. Base power flow for each wind speed.
6. Branch loading for each wind speed.
7. Whether fixed common accident-chain samples are used across wind speeds.
8. Whether the wind-speed scan uses the same outage probability parameters as the other tables.

## Model And Case Data

9. CloudPSS model parameters or exported case files.
10. Modified IEEE39 generator output table, load table, and line limit table.
11. Any OPF/economic dispatch setting used to construct base operating points.
12. Any table showing renewable output allocation across buses 30 to 39.

## Probability And Protection Parameters

13. Distance-protection hidden-failure parameters such as `P_W_D` and `ZIII`.
14. Loading hidden-failure parameters such as `P_L_D` and `P_L_r`.
15. Relay refusal / breaker refusal / breaker misoperation probabilities.
16. Whether Table 4-6 uses the same calibrated parameters as topology, penetration, and other scenarios.

## OLS And Severity Context

17. Whether the paper uses AC-OLS or DC-OLS.
18. OPF solver settings and whether soft constraints are allowed.
19. Whether OLS is triggered on non-convergence only or also on line/voltage violations.
20. Any exact line capacity and voltage boundary settings used in the risk calculation.

Without these inputs, the repository should continue to label the current results as diagnostic reproduction under public information constraints, not strict reproduction.
