
      program ave

      implicit none
      integer i, j, k, n , i1, i2, npts
      parameter (npts = 3000)
      double precision e, norm, sum_inten, emin, emax, e_onset, inten_onset
      double precision intensity(npts), energy(npts), area, de
      double precision energy2(npts), intensity2(npts)

     open (10,file='tmsftbroadave.dat',status='unknown',form='formatted')
      open (20,file='tmsftbroad_tt.dat', status='old',form='formatted')
      
      print *, 'enter number of excitations to average'
      read(*,*)n
!     n = 32
      intensity2(:) = 0.d0

      do j = 1, n
         do i = 1, npts
            read(20,*) energy(i), intensity(i)
            intensity2(i) = intensity2(i) + intensity(i)
         enddo
      enddo

      do i = 1, npts
         intensity2(i) = intensity2(i)/n
         energy2(i) = energy(i)
   
         !Added Charles Swartz (removed the norm)
         write(10,*) energy2(i),intensity2(i)

      enddo

!      ! find the first local maximum, which will be the xas onset ~ 535eV
!      e_onset     = 0.0d0
!      inten_onset = 0.0d0
!      do i = 1, npts
!        if ( intensity2(i) >= inten_onset ) then
!           inten_onset = intensity2(i)
!           e_onset     = energy2(i)
!        else 
!           write(*,*) "onset is found at ", e_onset, "eV"
!           GOTO 10
!        end if 
!      end do
!  10 CONTINUE
!
!! shift the averaged spectra to the onset and normalize the area betwee (530:550) to be 100
!      do i = 1, npts
!         energy2(i) = energy2(i) + 535.0d0 - e_onset
!         if( abs(energy2(i) - 532) .lt. 1E-3)i1 = i
!         if( abs(energy2(i) - 546) .lt. 1E-3)i2 = i
!      end do
!      
!      print *, energy2(i1), energy2(i2)
!
!      area = 0.d0
!      do i = i1, i2
!         area = area + intensity2(i)
!      enddo
!      area = area * (energy2(2)-energy2(1))
!      norm = 88.5/area
!     
!      do i = 1, npts
!         write(10,*) energy2(i),intensity2(i)*norm
!      enddo

      close(10)
      close(20)

      end
