C ---------------------------------------------------------------------- 
C  det: Calculate determinant of 3x3 matrix
C  Input: A (3x3 matrix)
C ---------------------------------------------------------------------- 
      function eq(STRESS)
          implicit none
          REAL*8 eq,STRESS
          dimension STRESS(6)
          eq=sqrt(STRESS(1)*STRESS(1)
     .      +STRESS(2)*STRESS(2)
     .      +STRESS(3)*STRESS(3)
     .      -STRESS(1)*STRESS(2)
     .      -STRESS(2)*STRESS(3)
     .      -STRESS(3)*STRESS(1)
     .      +3.0*(STRESS(4)*STRESS(4)
     .      +STRESS(5)*STRESS(5)
     .      +STRESS(6)*STRESS(6)))
      end



       SUBROUTINE VUMAT(
! READ ONLY - DO NOT MODIFY
     . NBLOCK, NDIR, NSHR, NSTATEV, NFIELDV, NPROPS, LANNEAL, STEPTIME,
     . TOTALTIME, DT, CMNAME, COORDMP, CHARLENGTH, PROPS, DENSITY,
     . STRAININC, RELSPININC, TEMPOLD, STRETCHOLD, DEFGRADOLD, FIELDOLD,
     . STRESSOLD, STATEOLD, ENERINTERNOLD, ENERINELASOLD, TEMPNEW,
     . STRETCHNEW, DEFGRADNEW, FIELDNEW,
! WRITE ONLY - DO NOT READ
     . STRESSNEW, STATENEW, ENERINTERNNEW, ENERINELASNEW)
!-----------------------------------------------------------------------
!     ABAQUS implicit variable declaration included in VABA_PARAM.INC
!     states the following:
!     a to h are REAL*8 variables
!     o to z are REAL*8 variables
!     i to n are integer variables
!-----------------------------------------------------------------------
      INCLUDE 'VABA_PARAM.INC'
!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
!     ABAQUS variables 
!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
      DIMENSION PROPS(NPROPS), DENSITY(NBLOCK), COORDMP(NBLOCK,*),
     . CHARLENGTH(*), STRAININC(NBLOCK,NDIR+NSHR), RELSPININC(*),
     . TEMPOLD(*), STRETCHOLD(*), FIELDOLD(*),
     . STRESSOLD(NBLOCK,NDIR+NSHR), STATEOLD(NBLOCK,NSTATEV),
     . ENERINTERNOLD(NBLOCK),  ENERINELASOLD(NBLOCK), TEMPNEW(*),
     . STRETCHNEW(*), DEFGRADNEW(*), FIELDNEW(*),
     . STRESSNEW(NBLOCK,NDIR+NSHR), STATENEW(NBLOCK,NSTATEV),
     . ENERINTERNNEW(NBLOCK), ENERINELASNEW(NBLOCK)
C
      CHARACTER*80 CMNAME
!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
!     Internal UMAT variables 
!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
      DIMENSION STRESS(NDIR+NSHR) ! Stress tensor inside UMAT
      DIMENSION DFDS(NDIR+NSHR)   ! Derivative of the yield function
      DIMENSION DFDS_J2(NDIR+NSHR)   ! Derivative of the yield function

      DIMENSION STRESSK(NDIR+NSHR)
      DIMENSION DSTRESSK(NDIR+NSHR)

      DIMENSION EP(NDIR+NSHR)
      DIMENSION DEP(NDIR+NSHR)
      DIMENSION DEFGRADOLD(nblock,ndir+nshr+nshr)
!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
!     Internal UMAT variables could be declared as follow
!     but it is not required due to the VABA_PARAM.INC file
!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
!   Material parameters
      REAL*8 YOUNG       ! Young's modulus 
      REAL*8 POISS       ! Poisson's ratio
      REAL*8 C11,C12,C44 ! Elasticity matrix C components
      REAL*8 SIGMA0      ! Initial yield stress
      REAL*8 ET          ! Tangent modulus
!   Internal variables
      REAL*8 P           ! Equivalent plastic strain
!   Plasticity variables
      REAL*8 DLAMBDA     ! Plastic multiplier
      REAL*8 DDLAMBDA    ! Increment in plastic multiplier
!   Yield function variables
      REAL*8 F           ! Yield function
      REAL*8 PHI_J2      ! Equivalent von mises stress
      REAL*8 PHI_I1      ! First stress invariant

      REAL*8 PHI         ! Equivalent stress
      REAL*8 SIGMAY      ! Yield stress
!   Computational variables
      REAL*8 RESNOR      ! Convergence criterion
      REAL*8 TOL         ! Tolerance for the RMAP algorithm
      INTEGER MXITER   ! Maximum number of iteration for the RMAP
      INTEGER ITER     ! Number of iteration for the RMAP
!   Added by newbie
      REAL*8 DFDP        ! Gradient of "Yield" criterion
      REAL*8 P0
      REAL*8 STRESSK
      REAL*8 DPDT

      REAL*8 DT

      REAL*8 P0DOT
      REAL*8 S
      REAL*8 SV
      REAL*8 DSVDP

      REAL*8 ALPHA

      REAL*8 CIIKK
      
      REAL*8 tst

      REAL*8 det
      
      REAL*8 presssign

      PARAMETER(three=3.0d0,two=2.0d0,one=1.0d0,zero=0.0d0)

      PHI = 0.0d0
      ALPHA = 0.5d0
      presssign = 1.0d0

!-----------------------------------------------------------------------
!     Read parameters from ABAQUS material card
!-----------------------------------------------------------------------
      YOUNG  = PROPS(1)
      POISS  = PROPS(2)
      SIGMA0 = PROPS(3)
      ET     = PROPS(4)!*zero
      S      = PROPS(5)*0.0d0
      P0DOT  = PROPS(6)
      TOL    = PROPS(7)
      MXITER = PROPS(8)
!-----------------------------------------------------------------------
!     Compute elasticity matrix
!-----------------------------------------------------------------------
      C11    = YOUNG*(1.0d0-POISS)/((1.0d0+POISS)*(1.0d0-2.0d0*POISS)) !la+2nu
      C12    = POISS*C11/(1.0d0-POISS) !Lame lambda
      C44    = 0.5d0*YOUNG/(1.0d0+POISS) !Lame nu
      CIIKK = three*YOUNG/(one-two*POISS)
!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
!     Loop over integration points
!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
      DO i=1,NBLOCK

            det = defgradOld(i,1)*defgradOld(i,2)*defgradOld(i,3)
     .        - defgradOld(i,4)*defgradOld(i,7)*defgradOld(i,3)
     .        - defgradOld(i,1)*defgradOld(i,5)*defgradOld(i,8)
     .        + defgradOld(i,9)*defgradOld(i,7)*defgradOld(i,8)
     .        + defgradOld(i,4)*defgradOld(i,5)*defgradOld(i,6)
     .        - defgradOld(i,9)*defgradOld(i,2)*defgradOld(i,6)


            print *,'det',det



!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
!        If time = 0 then pure elastic computation
!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
         IF(TOTALTIME.eq.0.0)THEN
            STRESSNEW(i,1) = STRESSOLD(i,1)+C11*STRAININC(i,1)
     .                       +C12*STRAININC(i,2)+C12*STRAININC(i,3)
            STRESSNEW(i,2) = STRESSOLD(i,2)+C12*STRAININC(i,1)
     .                       +C11*STRAININC(i,2)+C12*STRAININC(i,3)
            STRESSNEW(i,3) = STRESSOLD(i,3)+C12*STRAININC(i,1)
     .                       +C12*STRAININC(i,2)+C11*STRAININC(i,3)
            STRESSNEW(i,4) = STRESSOLD(i,4)+C44*STRAININC(i,4)*2.0d0
            STRESSNEW(i,5) = STRESSOLD(i,5)+C44*STRAININC(i,5)*2.0d0
            STRESSNEW(i,6) = STRESSOLD(i,6)+C44*STRAININC(i,6)*2.0d0
         ELSE
!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
!        Elastic-predictor-corrector scheme
!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
!-----------------------------------------------------------------------
!           Elastic prediction
!-----------------------------------------------------------------------
            STRESS(1) = STRESSOLD(i,1)+C11*STRAININC(i,1)
     .                                +C12*STRAININC(i,2)
     .                                +C12*STRAININC(i,3)
            STRESS(2) = STRESSOLD(i,2)+C12*STRAININC(i,1)
     .                                +C11*STRAININC(i,2)
     .                                +C12*STRAININC(i,3)
            STRESS(3) = STRESSOLD(i,3)+C12*STRAININC(i,1)
     .                                +C12*STRAININC(i,2)
     .                  +C11*STRAININC(i,3)-DLAMBDA*C44*DFDS(6)
            STRESS(4) = STRESSOLD(i,4)+C44*STRAININC(i,4)*2.0d0
            STRESS(5) = STRESSOLD(i,5)+C44*STRAININC(i,5)*2.0d0
            STRESS(6) = STRESSOLD(i,6)+C44*STRAININC(i,6)*2.0d0


            STRESSK(1) = STRESS(1)
            STRESSK(2) = STRESS(2)
            STRESSK(3) = STRESS(3)
            STRESSK(4) = STRESS(4)
            STRESSK(5) = STRESS(5)
            STRESSK(6) = STRESS(6)     
!-----------------------------------------------------------------------
!           Equivalent stress
!-----------------------------------------------------------------------
            PHI_J2       = sqrt(STRESSK(1)*STRESSK(1)
     .                      +STRESSK(2)*STRESSK(2)
     .                      +STRESSK(3)*STRESSK(3)
     .                      -STRESSK(1)*STRESSK(2)
     .                      -STRESSK(2)*STRESSK(3)
     .                      -STRESSK(3)*STRESSK(1)
     .                 +3.0d0*(STRESSK(4)*STRESSK(4)
     .                      +STRESSK(5)*STRESSK(5)
     .                      +STRESSK(6)*STRESSK(6)))

            PHI_I1 = (STRESSK(1)+STRESSK(2)+STRESSK(3))

            PHI = (PHI_J2 + ALPHA*PHI_I1)/(one+ALPHA)
!-----------------------------------------------------------------------
!           Equivalent plastic strain from previous time step
!-----------------------------------------------------------------------
            P         = STATEOLD(i,1) 
            P0        = STATEOLD(i,1)

            DEP(1) = 0.0d0
            DEP(2) = 0.0d0
            DEP(3) = 0.0d0
            DEP(4) = 0.0d0
            DEP(5) = 0.0d0
            DEP(6) = 0.0d0  
      

!-----------------------------------------------------------------------
!           Initialize the plastic multiplier
!-----------------------------------------------------------------------
            DLAMBDA  = 0.00000d0
!-----------------------------------------------------------------------
!           Update yield stress
!-----------------------------------------------------------------------
            SIGMAY   = SIGMA0+ET*P
!-----------------------------------------------------------------------
!           Compute yield function
!-----------------------------------------------------------------------
            F        = PHI-SIGMAY

!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
!           Check for plasticity
!$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
!-----------------------------------------------------------------------
!           Plastic flow
!-----------------------------------------------------------------------
            IF(F.GT.0.0d0)THEN ! Plastic flow
!-----------------------------------------------------------------------
!           Compute the derivative of the yield function
!-----------------------------------------------------------------------
                  IF(PHI.eq.0)THEN
                     DENOM = 1.0d0
                  ELSE
                     DENOM = PHI_J2
                  ENDIF
            presssign = PHI_I1/abs(PHI_I1)        
      
            DFDS_J2(1) = (STRESSK(1)-0.5d0*(STRESSK(2)+STRESSK(3)))
     .      /DENOM
            DFDS_J2(2) = (STRESSK(2)-0.5d0*(STRESSK(3)+STRESSK(1)))
     .      /DENOM
            DFDS_J2(3) = (STRESSK(3)-0.5d0*(STRESSK(1)+STRESSK(2)))
     .      /DENOM
                 DFDS_J2(4) = 3.0d0*STRESSK(4)/(two*DENOM) ! Think this should be divided by two
                 DFDS_J2(5) = 3.0d0*STRESSK(5)/(two*DENOM)
                 DFDS_J2(6) = 3.0d0*STRESSK(6)/(two*DENOM)

                 DFDS(1) = (DFDS_J2(1)+ALPHA)/(one+ALPHA)
                 DFDS(2) = (DFDS_J2(2)+ALPHA)/(one+ALPHA)
                 DFDS(3) = (DFDS_J2(3)+ALPHA)/(one+ALPHA)
                 DFDS(4) = (DFDS_J2(4))/(one+ALPHA)             
                 DFDS(5) = (DFDS_J2(5))/(one+ALPHA)             
                 DFDS(6) = (DFDS_J2(6))/(one+ALPHA)


!-----------------------------------------------------------------------
!           Determine viscous back stress
!-----------------------------------------------------------------------
            SV = S*log(one+DLAMBDA/(DT*P0DOT))
            DSVDP = S/(DT*P0DOT+DLAMBDA)
!-----------------------------------------------------------------------
!           Compute augmented yield function
!-----------------------------------------------------------------------
            F        = PHI-SIGMAY - SV
            DFDP     = ET +(3.0d0*C44+(alpha**two)*CIIKK)/
     .                  ((one+ALPHA)**two) +DSVDP

               DO ITER=1,MXITER
!-----------------------------------------------------------------------
!                 Compute increment in plastic multiplier
!-----------------------------------------------------------------------
                  DDLAMBDA  = F/DFDP
!-----------------------------------------------------------------------
!                 Update plastic multiplier and P
!-----------------------------------------------------------------------
                  DLAMBDA = DLAMBDA+DDLAMBDA
                  P      = P0 + DLAMBDA
!-----------------------------------------------------------------------
!                 Update viscous back stress
!-----------------------------------------------------------------------
                  tst = one+DLAMBDA/(DT*P0DOT)                  
                  IF(tst.GT.zero)THEN
                        SV = S*log(tst)
                        DSVDP = (S/(tst))/(DT*P0DOT)
                  ELSE
                        SV = S*log(-tst)
                        DSVDP = -(S/(-tst))/(DT*P0DOT)
                  ENDIF

!                 Determine plastic strains
                  DEP(1)= DLAMBDA*DFDS(1)
                  DEP(2)= DLAMBDA*DFDS(2)
                  DEP(3)= DLAMBDA*DFDS(3)
                  DEP(4)= DLAMBDA*DFDS(4)
                  DEP(5)= DLAMBDA*DFDS(5)
                  DEP(6)= DLAMBDA*DFDS(6)

!-----------------------------------------------------------------------
!                 Update stress
!-----------------------------------------------------------------------
            DSTRESSK(1) = C11*DEP(1)+C12*DEP(2)
     .                    +C12*DEP(3)
            DSTRESSK(2) = C12*DEP(1)+C11*DEP(2)
     .                    +C12*DEP(3)
            DSTRESSK(3) = C12*DEP(1)+C12*DEP(2)
     .                    +C11*DEP(3)
            DSTRESSK(4) = C44*two*DEP(4)
            DSTRESSK(5) = C44*two*DEP(5)
            DSTRESSK(6) = C44*two*DEP(6)


                  STRESSK(1)= STRESS(1)-DSTRESSK(1)
                  STRESSK(2)= STRESS(2)-DSTRESSK(2)
                  STRESSK(3)= STRESS(3)-DSTRESSK(3)
                  STRESSK(4)= STRESS(4)-DSTRESSK(4)
                  STRESSK(5)= STRESS(5)-DSTRESSK(5)
                  STRESSK(6)= STRESS(6)-DSTRESSK(6)
                 
!-----------------------------------------------------------------------
!                 Update yield stress
!-----------------------------------------------------------------------
                  SIGMAY   = SIGMA0+ET*P
!-----------------------------------------------------------------------
!                 Equivalent stress
!-----------------------------------------------------------------------
            PHI_J2       = sqrt(STRESSK(1)*STRESSK(1)
     .                      +STRESSK(2)*STRESSK(2)
     .                      +STRESSK(3)*STRESSK(3)
     .                      -STRESSK(1)*STRESSK(2)
     .                      -STRESSK(2)*STRESSK(3)
     .                      -STRESSK(3)*STRESSK(1)
     .                 +3.0d0*(STRESSK(4)*STRESSK(4)
     .                      +STRESSK(5)*STRESSK(5)
     .                      +STRESSK(6)*STRESSK(6)))

            PHI_I1 = STRESSK(1)+STRESSK(2)+STRESSK(3)

            PHI = (PHI_J2 + ALPHA*PHI_I1)/(one+ALPHA)
!-----------------------------------------------------------------------
!                 Compute augmented yield function and gradient
!-----------------------------------------------------------------------
                  F        = PHI-SIGMAY - SV
                  DFDP     = ET +(3.0d0*C44+(alpha**two)*CIIKK)/
     .                  ((one+ALPHA)**two) +DSVDP


!-----------------------------------------------------------------------
!                 Compute the derivative of the yield function
!-----------------------------------------------------------------------

                  IF(PHI.eq.0)THEN
                     DENOM = 1.0d0
                  ELSE
                     DENOM = PHI_J2
                  ENDIF
            presssign = PHI_I1/abs(PHI_I1)        
      
            DFDS_J2(1) = (STRESSK(1)-0.5d0*(STRESSK(2)+STRESSK(3)))
     .      /DENOM
            DFDS_J2(2) = (STRESSK(2)-0.5d0*(STRESSK(3)+STRESSK(1)))
     .      /DENOM
            DFDS_J2(3) = (STRESSK(3)-0.5d0*(STRESSK(1)+STRESSK(2)))
     .      /DENOM
                 DFDS_J2(4) = 3.0d0*STRESSK(4)/(two*DENOM)
                 DFDS_J2(5) = 3.0d0*STRESSK(5)/(two*DENOM)
                 DFDS_J2(6) = 3.0d0*STRESSK(6)/(two*DENOM)

                 DFDS(1) = (DFDS_J2(1)+ALPHA)/(one+ALPHA)
                 DFDS(2) = (DFDS_J2(2)+ALPHA)/(one+ALPHA)
                 DFDS(3) = (DFDS_J2(3)+ALPHA)/(one+ALPHA)
                 DFDS(4) = (DFDS_J2(4))/(one+ALPHA)             
                 DFDS(5) = (DFDS_J2(5))/(one+ALPHA)             
                 DFDS(6) = (DFDS_J2(6))/(one+ALPHA)

!-----------------------------------------------------------------------
!                 Plot things
!-----------------------------------------------------------------------
                  print *,'DT', DT
                  print *,'DLAMBDA', DLAMBDA
                  print *,'DDLAMBDA', DDLAMBDA
                  print *,'PHI', PHI
                  print *,'F', F
                  print *,'SV', SV
                  print *,'DSVDP',DSVDP
                  print *,'DFDP', DFDP
                  print *,'F updated', F
                  print *,'DFDP updated', DFDP
                  print *,'SV updated', SV
                  print *,'Plastic',P
                  print *, 'tst',tst
                  print *, 'defgrad',DEFGRADOLD(i,1)
                  print *,'DFDS', DFDS(1)
                  print*, 'Stressk', STRESS(1)

 
                  print*,'Volumetric strain',DEP(1)+DEP(2)+DEP(3)

!-----------------------------------------------------------------------
!                 Compute convergence criterion
!-----------------------------------------------------------------------
                  RESNOR = ABS((F)/SIGMAY)
!-----------------------------------------------------------------------
!                 Check for convergence
!-----------------------------------------------------------------------
                  IF(RESNOR.LE.TOL.AND.DLAMBDA.GE.zero)THEN ! RMAP has converged
                        PRINT *, 'Converged in', ITER

!-----------------------------------------------------------------------
!                    Update the stress tensor
!-----------------------------------------------------------------------
                        STRESSNEW(i,1) = STRESSK(1)
                        STRESSNEW(i,2) = STRESSK(2)
                        STRESSNEW(i,3) = STRESSK(3)
                        STRESSNEW(i,4) = STRESSK(4)
                        STRESSNEW(i,5) = STRESSK(5)
                        STRESSNEW(i,6) = STRESSK(6)

!-----------------------------------------------------------------------
!                    Update the history variables
!-----------------------------------------------------------------------
                     STATENEW(i,1) = P
                     STATENEW(i,2) = PHI-3.0*C44*DLAMBDA
                     STATENEW(i,3) = F
                     STATENEW(i,4) = SIGMAY
                     STATENEW(i,5) = DGAMA
                     STATENEW(i,6) = ITER

                     STATENEW(i,7) = STATEOLD(i,7) + DEP(1)
                     STATENEW(i,8) = STATEOLD(i,8) + DEP(2)
                     STATENEW(i,9) = STATEOLD(i,9) + DEP(3)
                     STATENEW(i,10) =STATEOLD(i,10) + DEP(4)
                     STATENEW(i,11) =STATEOLD(i,11) + DEP(5)
                     STATENEW(i,12) =STATEOLD(i,12) + DEP(6)

                     GOTO 90
                  ELSE ! RMAP has not converged yet
                     IF(ITER.eq.MXITER)THEN
                        write(*,*) 'RMAP has not converged'
                        write(*,*) 'Integration point',i
                        write(*,*) 'Convergence',RESNOR
                        write(*,*) 'dlambda',DLAMBDA,P
                        STOP
                     ENDIF
                  ENDIF          
               ENDDO
!-----------------------------------------------------------------------
!           Elastic point
!-----------------------------------------------------------------------
            ELSE
!-----------------------------------------------------------------------
!              Update the stress tensor
!-----------------------------------------------------------------------
               STRESSNEW(i,1) = STRESS(1)
               STRESSNEW(i,2) = STRESS(2)
               STRESSNEW(i,3) = STRESS(3)
               STRESSNEW(i,4) = STRESS(4)
               STRESSNEW(i,5) = STRESS(5)
               STRESSNEW(i,6) = STRESS(6)
!-----------------------------------------------------------------------
!              Update the history variables
!-----------------------------------------------------------------------
               STATENEW(i,1) = P
               STATENEW(i,2) = PHI
               STATENEW(i,3) = F
               STATENEW(i,4) = SIGMAY
               STATENEW(i,5) = 0.0
               STATENEW(i,6) = 0
               STATENEW(i,7) = STATEOLD(i,7)
               STATENEW(i,8) = STATEOLD(i,8)
               STATENEW(i,9) = STATEOLD(i,9)
               STATENEW(i,10) =STATEOLD(i,10)
               STATENEW(i,11) =STATEOLD(i,11)
               STATENEW(i,12) =STATEOLD(i,12)
            ENDIF
!-----------------------------------------------------------------------
!        End of loop over integration points
!-----------------------------------------------------------------------
         ENDIF           
  90     CONTINUE  
      ENDDO
!-----------------------------------------------------------------------
!     END SUBROUTINE
!-----------------------------------------------------------------------
      RETURN
      END
