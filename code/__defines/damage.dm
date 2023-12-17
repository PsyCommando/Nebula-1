//////////////////////////////////////////////////////////////////////////
// Health Constants
//////////////////////////////////////////////////////////////////////////

///The decimal precision for health values. Health will be rounded against this value.
#define HEALTH_ROUNDING 0.01

//////////////////////////////////////////////////////////////////////////
// Damage Types
//////////////////////////////////////////////////////////////////////////

///Melee physical damage
#define BRUTE       "brute"
///Fire, chemical, cold exposure damage
#define BURN        "fire"
///Toxin damage inflicted to biologic entities
#define TOX         "tox"
///Oxygen deprivation damage dealt to organs
#define OXY         "oxy"
///(Probably Deprecated) Damage done to mobs from bad cloning, or dna damage.
#define CLONE       "clone"
///Non-lethal pain damage inflicted to mobs.
#define PAIN        "pain"
///Electrical damage
#define ELECTROCUTE "electrocute"
///Ionizing radiation exposure damage.
#define IRRADIATE   "irradiate"

//////////////////////////////////////////////////////////////////////////
// Damage flags
//////////////////////////////////////////////////////////////////////////

///Damage has the sharp property and may cause cuts and bleeding.
#define DAM_SHARP     BITFLAG(0)
///Damage may cause dismemberment.
#define DAM_EDGE      BITFLAG(1)
///Damage causes localized burns.
#define DAM_LASER     BITFLAG(2)
///Damage is caused by high velocity projectiles.
#define DAM_BULLET    BITFLAG(3)
///Damage was dealt from an explosion.
#define DAM_EXPLODE   BITFLAG(4)
/// Makes apply_damage calls without specified zone distribute damage rather than randomly choose organ (for humans)
#define DAM_DISPERSED BITFLAG(5)
/// Toxin damage that should be mitigated by biological (i.e. sterile) armor
#define DAM_BIO       BITFLAG(6)
///Flag for damage that should be applied raw with no mitigation/modifiers. Meant for internal damage, like organs damaging themselves, or parts wearing down or something.
#define DAM_RAW       BITFLAG(7)
