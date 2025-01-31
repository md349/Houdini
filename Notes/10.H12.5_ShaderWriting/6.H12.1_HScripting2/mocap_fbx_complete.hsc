# MOCAP SETUP HSCRIPT - TASK LIST

# DEFINE MOCAP SKELETON HIERARCHY NUMBERING
# DEFINE MOCAP REST POSE FBX NAME

##### USER DEFINED VARIBLES #####

# NOTES TO USER:
# Modify the RANGELIST variable to identify all beginning
# and end joint node chains of your FBX skeleton heirachy...
# Modify the TPOSE variable to the name of your
# T-POSE / REST POSE fbx subnetwork

set RANGELIST = 1_6 7_11 12_19 20_24 25_27
set TPOSE = rest_pose_fbx

##### END USER DEFINED VARIABLES #####



# AT OBJ LEVEL CYCLE THROUGH EACH SCENE OBJECT TO DETERMINE IF IT IS A FBX MOCAP CLIP

opcf /obj

# create empty list for fbx objects
set FBXOBJECTLIST = " "

# examine each scene object in turn

foreach OBJECT ( `execute("opls")` )

    # DETERMINE THE OBJECT TYPE
    set OBJECT_TYPE = `execute("optype -t $OBJECT")`

    # DETERMINE IF THE OBJECT NAME MATCHES *_fbx, AND THE OBJECT TYPE IS A SUBNET

    if ( `strmatch("*_fbx",$OBJECT)` == 1 && $OBJECT_TYPE == subnet)

    # IF YES, ADD THE FOUND FBX CLIP TO A CLIP LIST
    set FBXOBJECTLIST = `strcat($FBXOBJECTLIST + " ", $OBJECT)`
    endif

end

# ASK THE USER TO VERIFY THE FOUND FBX MOCAP CLIPS AND INDICATE IF THEY WISH TO PROCEED WITH THE REST OF THE SCRIPT

set ANSWER = `run("message -b Yes,No Found MOCAP CLIPS:\n$FBXOBJECTLIST\n\n Would you like to proceed with the MOCAP Setup Script?")`

# IF YES, KEEP KEY VARIABLES AND CONTINUE - IF NO EXIT SCRIPT AND UNSET SCRIPT VARIABLES

if ( $ANSWER == 1 )
    set -u RANGELIST TPOSE FBXOBJECTLIST OBJECT OBJECT_TYPE ANSWER
    exit
else
    set -u OBJECT OBJECT_TYPE ANSWER
endif

message Yes was pressed


# DEFINE NAMES FOR KEY CHOP OPERATORS BEING CREATED
# define CHOP Network Name
set CNET = MOCAP_CONTROL

# REMOVE PREVIOUS ITERATIONS OF THIS SCRIPT
opcf /obj
oprm -f $CNET

# CREATE A CUSTOM CHOP NETWORK FOR MOCAP DATA AND GO INSIDE IT
opadd -n chopnet $CNET
opcf /obj/$CNET

        # CREATE A SWITCH CHOP
        opadd -n switch MOCAP_CONTROL_SWITCH
        # CREATE A RENAME CHOP
        opadd -n rename MOCAP_EXPORT
        # SET THE PARAMETERS ON THE RENAME CHOP
        opparm MOCAP_EXPORT renamefrom ( * ) renameto ( /obj/$TPOSE/* )
        # WIRE THE SWITCH CHOP INTO THE RENAME CHOP
        opwire -n MOCAP_CONTROL_SWITCH -0 MOCAP_EXPORT
        # ACTIVATE THE DISPLAY FLAG ON THE RENAME CHOP
        opset -d on MOCAP_EXPORT


# CREATE TWO COUNT VARIABLES
set INC = 0
set INC2 = 0

# EXAMINE EACH FBX CLIP IN TURN
foreach OBJECT ( $FBXOBJECTLIST )

    # CREATE A MERGE CHOP FOR EACH FOUND OBJECT
    opadd -n merge $OBJECT
    # WIRE THE MERGE CHOPS INTO THE SWITCH CHOP
    opwire -n $OBJECT -$INC MOCAP_CONTROL_SWITCH
    # INCREASE THE COUNT VARIABLE
    set INC = `$INC + 1`

        # IF A FBX MOCAP CLIP IS FOUND, IMPORT IT INTO THE CUSTOM CHOP NETWORK USING OBJECT CHAIN CHOPS
        foreach RANGE ( $RANGELIST)
            # CREATE A FULLNAME FOR THE OBJECT CHAIN CHOP TO BE CREATED
            set FULLNAME = $OBJECT"_"$RANGE
            # CREATE A TEMPORARY LIST USING $RANGE BUT REMOVING THE UNDERSCORE
            set TEMPLIST = `strreplace($RANGE, "_", " ")`
            # EXTRACT THE BEGINNING AND END NUMBERS OF TEMPLIST AS NEW VARIABLES
            set NUMSTART = `arg($TEMPLIST, 0)`
            set NUMEND = `arg($TEMPLIST, 1)`

            # CREATE THE OBJECT CHAIN CHOP USING THE FULLNAME VARIABLE
            opadd -n objectchain $FULLNAME

            # SET THE PARAMETER PATHS DIFFERENTLY FOR THE REST POSE FBX CLIP
                if ( $OBJECT != $TPOSE ) then
                    opparm $FULLNAME startpath ( /obj/$OBJECT/reference/joint$NUMSTART )
                    opparm $FULLNAME endpath ( /obj/$OBJECT/reference/joint$NUMEND )
                else
                    opparm $FULLNAME startpath ( /obj/$OBJECT/joint$NUMSTART )
                    opparm $FULLNAME endpath ( /obj/$OBJECT/joint$NUMEND )
                endif
            # UNTICK THE PRETRANSFORM NAME FOR ALL OBJECT CHAIN CHOPS
            opparm $FULLNAME fetchpretransform (off)
            

            # WIRE THE OBJECT CHAIN CHOP INTO THE ASSOCIATED MERGE CHOP
            opwire -n $FULLNAME -$INC2 $OBJECT
            # INCREASE THE SECOND COUNT VARIABLE BY 1 TO FACILITATE THE NEXT ITTERATION OF THE NESTED FOR EACH LOOP
            set INC2 = `$INC2 + 1`
        end
end

# ACTIVATE THE ORANGE EXPORT FLAG ON THE RENAME CHOP
opset -o on MOCAP_EXPORT

# LOCK THE REST POSE MERGE CHOP TO PREVENT RECURSION ERRORS
opset -l on $TPOSE

# TIDY UP THE AUTOMATICALLY GENERATED NODES
oplayout -d 0

