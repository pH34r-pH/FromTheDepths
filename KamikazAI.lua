-- Made by _pH34_ (Tyler H) for From the Depths
-- First (that I know of) effective Lua remote control of ships by ships
-- Step 1 of creating FTD Skynet


-- Don't change these --
LastSpinnerCount = 5
LeftSponson = 0
LeftThruster = 1
RightThruster = 3
RightSponson = 2
PitchThruster = 4

RollDamper = 0
LeftThrustAdjust = 0
RightThrustAdjust = 0
PitchAdjust = 0
AltitudeAdjust = 0

CruisingAltitude = 400

DefaultThrust = -1.65
Angle = 90
LeftAngleAdjust = 0
RightAngleAdjust = 0
Mode = 0

SelfId = 0
MothershipId = -1


-- User Editable --

-- In degrees. Tweaking these may aid or totally screw stability
RollTolerance = 2
SevereRoll = 5
PitchTolerance = 1
AltitudeTolerance = 3
TargetTolerance = 7.5

-- Applied as adjustments to spin blocks with a max speed of 30.
-- Smaller steps may make smoother, slower reactions to roll/pitch errors.
AltitudeSensitivity = -1

RollSensitivity = -0.02
PitchSensitivity = -0.5

-- Min Alt + Max Alt = actual max altitude
MinCruiseAlt = 50
MaxCruiseAlt = 300

-- Used for turning log statements on/off
-- sort-of, kind-of implemented
Debug = 1

-- End Variables --

function Update(I)
    -- Attempt at programmatically identifying spinners correctly
    -- sort of works, but not entirely. currently building from blueprint
    -- creates a crippled drone
    if Mode == 0 or not I:GetSpinnerCount() == LastSpinnerCount then
        LastSpinnerCount = I:GetSpinnerCount()
        for ii=0, (I:GetSpinnerCount() - 1) do
            Spinner = I:GetSpinnerInfo(ii)
            if Spinner.LocalPosition.x > 0 then 
                RightSponson = ii
            elseif Spinner.LocalPosition.x < 0 then 
                LeftSponson = ii
            elseif Spinner.LocalPosition.z > 0 then 
                PitchThruster = ii
            end
        end
    end
    if Mode == 0 then
        SelfId = I:GetFriendlyCount()
        I:LogToHud("Drone " .. SelfId .. " Active.")
        SetThrusterAngle(I)
        SetThrust(I, DefaultThrust)
        -- Each drone gets a unique cruising altitude to reduce chances of crashing
        CruisingAltitude = MaxCruiseAlt - ((SelfId * (AltitudeTolerance * 2)) % MaxCruiseAlt) + MinCruiseAlt
        for j=0, I:GetFriendlyCount() do
            if I:GetFriendlyInfo(j).BlueprintName == "Mothership" then
                MothershipId = I:GetFriendlyInfo(j).Id
                j = I:GetFriendlyCount() + 1
                I:LogToHud("Mothership Found. (" .. SelfId .. ")")
                break
            end
        end
        if MothershipId == -1 then
            I:LogToHud("Mothership Not Found! (" .. SelfId .. ")")
        end
        Mode = 1
    elseif Mode == 1 then 
        Hover(I)
    elseif Mode == 2 or Mode == 3 then
        Fly(I)
    elseif Mode == 4 then
        Hibernate(I)
    end
    Mode = CheckForCommand(I)

end

function CheckForCommand(I)
    if MothershipId == -1 then 
        if (I:GetConstructPosition().y > CruisingAltitude - AltitudeTolerance) or
           (Mode == 2 and I:GetConstructPosition().y > CruisingAltitude - (AltitudeTolerance * 40)) then
            return 2
        else 
            TargetId = -1
            if I:GetNumberOfTargets(0) > 0 then
                LastRange = 50000
                for ii = 0, I:GetNumberOfTargets(0) do 
                    TargetOption = I:GetTargetInfo(0, ii)
                    if TargetOption.Valid then
                        Range = I:GetTargetPositionInfo(0, ii).Range
                        if Range < LastRange then
                            LastRange = Range
                            TargetId = ii
                            break
                        end
                    end
                end
            end
            if TargetId == -1 then
                return 1
            else
                return 2
            end
        end
    else
        Info = I:GetFriendlyInfoById(MothershipId)
        -- This section is attempting to get the mothership heading in order to adjust the XVal and ZVal
        -- so that the mothership doesn't have to remain pointed at 0 degrees.
        -- Another solution involves keeping the selector arm pointed at 0 degrees rather than the motherships
        -- front as a default position.
        Rotation = math.deg(math.atan(Info.ForwardVector.x,Info.ForwardVector.z)) * 2
        X = (Info.CenterOfMass - Info.ReferencePosition).x
        Z = (Info.CenterOfMass - Info.ReferencePosition).z
        XVal = (Z * math.sin(Rotation)) + (X * math.cos(Rotation))
        ZVal = (X * math.sin(Rotation)) + (Z * math.cos(Rotation))

        -- This is a heavily simplified proof-of-concept implementation, because I could hardly find
        -- a purpose for 4 modes, much less the nearly unlimited modes of using pure vectors.
        if XVal > 0 and ZVal > 0 then 
            if not Mode == 1 then
                I:LogToHud("Switching to Hover Mode. (" .. SelfId .. ")")
            end
            return 1
        elseif XVal < 0 and ZVal > 0 then 
            if not Mode == 2 then
                I:LogToHud("Switching to Fly Mode. (" .. SelfId .. ")")
            end
            return 2
        elseif XVal < 0 and ZVal < 0 then 
            if not Mode == 3 then
                -- not implemented yet
                I:LogToHud("Switching to Return Mode. (" .. SelfId .. ")")
            end
            return 3
        elseif XVal > 0 and ZVal < 0 then 
            if not Mode == 4 then
                I:LogToHud("Switching to Hibernate Mode. (" .. SelfId .. ")")
            end
            return 4
        end
    end
end

function Hibernate(I)
    Angle = 90
    SetThrusterAngle(I)
    SetThrust(I, 0)
end

function Fly(I)
    Roll = I:GetConstructRoll()
    Pitch = I:GetConstructPitch()
    Altitude = I:GetConstructPosition().y
    Angle = 5
    SteeringDifference = -0.2
    DefaultThrust = -23
    TargetId = -1

    if I:GetNumberOfTargets(0) > 0 then
        LastRange = 50000
        for ii = 0, I:GetNumberOfTargets(0) do 
            TargetOption = I:GetTargetInfo(0, ii)
            if TargetOption.Valid then
                if TargetOption.PlayerTargetChoice then
                    TargetId = ii
                    break
                else
                    Range = I:GetTargetPositionInfo(0, ii).Range
                    if Range < LastRange then
                        LastRange = Range
                        TargetId = ii
                    end
                end
            end
        end
    end
    TargetPInfo = I:GetTargetPositionInfo(0, TargetId)

    if Mode == 3 then 
        MInfo = I:GetFriendlyInfoById(MothershipId)
        TargetPInfo = I:GetTargetPositionInfoForPosition(0, 
                                                        MInfo.ReferencePosition.x,
                                                        MInfo.ReferencePosition.y,
                                                        MInfo.ReferencePosition.z)
    end

    Elevation = TargetPInfo.ElevationForAltitudeComponentOnly
    Azimuth = math.abs(TargetPInfo.Azimuth)

    if not (TargetId == -1) or (Mode == 3) then
        
        if Azimuth > TargetTolerance and Azimuth < 180 then
            LeftThrustAdjust = SteeringDifference * Azimuth
            RightThrustAdjust = -SteeringDifference * Azimuth
        elseif Azimuth >= 180 and Azimuth < (360 - TargetTolerance) then
            LeftThrustAdjust = -SteeringDifference * (360 - Azimuth)
            RightThrustAdjust = SteeringDifference * (360 - Azimuth)
        else
            LeftThrustAdjust = 0
            RightThrustAdjust = 0
        end
        if (Pitch > 40 and Pitch < 180) or (Pitch < 320 and Pitch > 180)then
            LeftThrustAdjust = 0
            RightThrustAdjust = 0
        end
    end
    
    if Pitch > (PitchTolerance * 2) and Pitch < 180 then 
        PitchAdjust = -((Pitch / PitchTolerance) * PitchSensitivity)
    elseif Pitch < (360 - (PitchTolerance * 2)) and Pitch > 180 then
        PitchAdjust = (((360 - Pitch) / PitchTolerance) * PitchSensitivity)
    else
        PitchAdjust = 1
    end

    if (Pitch > PitchTolerance * 3 and Pitch < 180) or 
       (Pitch < (360 - (PitchTolerance * 3)) and Pitch > 180) then
        PitchAdjust = 10
    end

    if (Altitude < CruisingAltitude - (AltitudeTolerance * 20)) then 
        PitchAdjust = PitchAdjust + 1
    elseif Altitude > 450 then 
        LeftThrustAdjust = 50
        RightThrustAdjust = 50
        PitchAdjust = 25
    elseif (Altitude > CruisingAltitude + AltitudeTolerance) then 
        PitchAdjust = PitchAdjust - 1
    end

    if Elevation < -TargetTolerance and Altitude > 5 then 
        PitchAdjust = PitchAdjust + (Elevation * -0.5)
    elseif Elevation > TargetTolerance then
        PitchAdjust = PitchAdjust - (Elevation * 0.5)
    end

    if TargetPInfo.Range < 300 and math.abs(Elevation) < TargetTolerance and 
          (Azimuth > (360 - TargetTolerance) or Azimuth < TargetTolerance) then
        I:FireWeapon(0,0)
    end

    SetThrust(I, DefaultThrust)
    SetThrusterAngle(I)
end

function Hover(I)
    Roll = I:GetConstructRoll()
    Pitch = I:GetConstructPitch()
    Altitude = I:GetConstructPosition().y
    Angle = 90
    DefaultThrust = -1.65

    if Altitude > CruisingAltitude + AltitudeTolerance then
        AltitudeAdjust = -AltitudeSensitivity
    elseif Altitude < CruisingAltitude - AltitudeTolerance then
        AltitudeAdjust = AltitudeSensitivity
    else
        AltitudeAdjust = 0
    end
--[[ Removed after adding jet stabilisers -- code kept in case I want to make an Osprey
    if Roll > RollTolerance and Roll < (RollTolerance * SevereRoll) then
        RollDamper = 0
        LeftThrustAdjust = ((Roll / RollTolerance) * RollSensitivity)
        RightThrustAdjust = -((Roll / RollTolerance) * RollSensitivity)
    elseif Roll < 360 - RollTolerance and Roll > 360 - (RollTolerance * SevereRoll) then
        RollDamper = 0
        LeftThrustAdjust = -((-(360-Roll) / RollTolerance) * RollSensitivity)
        RightThrustAdjust = ((-(360-Roll) / RollTolerance) * RollSensitivity)
    elseif Roll > (RollTolerance * SevereRoll) and Roll < 180 then
        RollDamper = RollDamper + 1
        LeftThrustAdjust = RollSensitivity
        RightThrustAdjust = -((DefaultThrust * math.max(0.07, ((7.5 - RollDamper) / 10)) * ((RollTolerance * SevereRoll) / Roll))
 - math.abs(AltitudeAdjust))
    elseif Roll > 180 and Roll < 360 - (RollTolerance * SevereRoll) then
        RollDamper = RollDamper + 1
        LeftThrustAdjust = -((DefaultThrust * math.max(0.07, ((7.5 - RollDamper) / 10)) * (Roll / (360 -(RollTolerance * SevereRoll)))) - math.abs(AltitudeAdjust))
        RightThrustAdjust = RollSensitivity
    else 
        RollDamper = 0
        LeftThrustAdjust = 0
        RightThrustAdjust = 0
    end

]]--
    if Pitch > PitchTolerance and Pitch < 180 then 
        PitchAdjust = -((Pitch / PitchTolerance) * PitchSensitivity)
    elseif Pitch < (360 - PitchTolerance) and Pitch > 180 then
        PitchAdjust = ((Pitch / PitchTolerance) * PitchSensitivity)
    else
        PitchAdjust = 0
    end

    SetThrusterAngle(I)
    SetThrust(I, DefaultThrust)
end

function SetThrust(I, speed)
    if I:IsSpinnerDedicatedHelispinner(RightThruster) then
        I:SetSpinnerContinuousSpeed(RightThruster, (speed + RightThrustAdjust + AltitudeAdjust))
    end
    if I:IsSpinnerDedicatedHelispinner(LeftThruster) then
        I:SetSpinnerContinuousSpeed(LeftThruster, (speed + LeftThrustAdjust + AltitudeAdjust))
    end
    if I:IsSpinnerDedicatedHelispinner(PitchThruster) then
        I:SetSpinnerContinuousSpeed(PitchThruster, PitchAdjust)
    end
end

function SetThrusterAngle(I)
    I:SetSpinnerRotationAngle(LeftSponson, Angle + LeftAngleAdjust)
    I:SetSpinnerRotationAngle(RightSponson, (Angle + RightAngleAdjust)* -1)    
end
