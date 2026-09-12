* AMCAS TakeHomeLab Task 3 - VDD sweep: sense margin vs supply
* Q=0, QB=1 stored. Sweep VDD 1.1 -> 0.6 V in 50 mV steps, measure dV at a
* FIXED sense window, and find where dV drops under the 25 mV sense-amp offset.
.include ../45nm_bulk.txt $ PTM BSIM4 card

.param VDD=1.1 VBL=1.1
.param WACC=0.16u

Vdd vdd 0 'VDD'
Vwl wl  0 PWL(0 0 1n 0 1.05n 'VDD')

MP1 qb q  vdd vdd pmos W=0.15u  L=0.045u
MN1 qb q  0   0   nmos W=0.20u  L=0.045u
MP2 q  qb vdd vdd pmos W=0.15u  L=0.045u
MN2 q  qb 0   0   nmos W=0.20u  L=0.045u
MA1 bl  wl q  0   nmos W='WACC' L=0.045u
MA2 blb wl qb 0   nmos W='WACC' L=0.045u

Cbl  bl  0 180f IC='VBL'
Cblb blb 0 180f IC='VBL'

.ic v(q)=0 v(qb)='VDD'

.control
   set noaskquit
   let nsteps = 11
   let n      = 0
   let vsweep = unitvec(nsteps)      $ VDD axis
   let dv_s   = unitvec(nsteps)      $ dV at the 65 ps sense window
   let dv_2n  = unitvec(nsteps)      $ dV at t = 2 ns (assignment point)
   let qpk    = unitvec(nsteps)      $ read disturb peak

   while n < nsteps
      let vnow = 1.1 - n * 0.05

      alter Vdd        = vnow        $ supply
      alter @cbl[ic]   = vnow        $ bitlines precharge to VDD
      alter @cblb[ic]  = vnow
      alter Vwl pwl = [ 0 0 1n 0 1.05n $&vnow ]   $ WL amplitude tracks VDD

      tran 5p 4n uic

      let dvbl = v(blb)-v(bl)
      meas tran m_dvs FIND dvbl AT=1.115n
      meas tran m_dv2 FIND dvbl AT=2.0n
      meas tran m_qpk MAX  v(q) FROM=1n TO=4n

      let vsweep[n] = vnow
      let dv_s[n]   = m_dvs
      let dv_2n[n]  = m_dv2
      let qpk[n]    = m_qpk

      print vnow m_dvs m_dv2 m_qpk
      let n = n + 1
   end

   * ---- results ----
   setplot const                     $ sweep vectors live in the const plot
   setscale vsweep

   let offset = 0.025 * unitvec(nsteps)   $ 25 mV sense-amp offset, Lecture 5

   * first VDD (walking down) where dV falls below the offset, linearly interpolated
   let k = 0
   let vcross = 0
   while k < nsteps-1
      if (dv_s[k] >= 0.025) & (dv_s[k+1] < 0.025)
         let vcross = vsweep[k] - 0.05 * (dv_s[k]-0.025) / (dv_s[k]-dv_s[k+1])
      end
      let k = k + 1
   end
   print vcross

   plot dv_s offset vs vsweep
   +    xlabel 'VDD (V)' ylabel 'dV(BLB-BL) at 65 ps window (V)'
   +    title 'Task 3: sense margin vs supply'

   wrdata task3_sweep.csv dv_s dv_2n qpk
.endc
.end
