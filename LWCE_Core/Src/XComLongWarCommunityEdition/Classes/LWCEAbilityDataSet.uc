class LWCEAbilityDataSet extends LWCEDataSet;

//---------------------------------------------------------------------------------------
// Default variables for use when creating templates. Much like XCOM 2, these simplify template
// creation by providing pre-created values for many common scenarios. These variables should not
// be modified in any way.
//---------------------------------------------------------------------------------------

var LWCEAbilityToHitCalc_DeadEye DeadEye;
var LWCEAbilityToHitCalc_StandardAim SimpleStandardAim;
var LWCECondition_UnitProperty LivingShooterProperty;
var LWCECondition_UnitProperty LivingHostileTargetProperty;
var LWCEAbilityTrigger_UnitPostBeginPlay UnitPostBeginPlayTrigger;
var LWCEAbilityTargetStyle_Self SelfTarget;
var LWCEAbilityTargetStyle_Single SimpleSingleTarget;
var LWCECondition_Visibility VisibleToSourceCondition;

static function array<LWCEDataTemplate> CreateTemplates()
{
    local array<LWCEDataTemplate> arrTemplates;

    arrTemplates.AddItem(Ranger());
    arrTemplates.AddItem(StandardShot());

    return arrTemplates;
}

static function LWCEAbilityTemplate Ranger()
{
	local LWCEAbilityTemplate Template;
	local LWCEEffect_Ranger RangerEffect;

	`CREATE_ABILITY_TEMPLATE(Template, 'Ranger');

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.UnitPostBeginPlayTrigger);

	RangerEffect = new class'LWCEEffect_Ranger';
	RangerEffect.BuildPersistentEffect(1, /* bIsInfinite */ true);
	Template.AbilityTargetEffects.AddItem(RangerEffect);

	return Template;
}

static function LWCEAbilityTemplate StandardShot()
{
	local LWCEAbilityTemplate Template;
    local LWCEAbilityCost_ActionPoints kActionPointsCost;
    local LWCEAbilityCost_Ammo kAmmoCost;
    local LWCECondition_Visibility kVisCondition;
	local LWCEEffect_ApplyWeaponDamage kEffect;

	`CREATE_ABILITY_TEMPLATE(Template, 'StandardShot');

    Template.AbilityIcon = "Standard";

    kActionPointsCost = new class'LWCEAbilityCost_ActionPoints';
    kActionPointsCost.iNumPoints = 1;
    kActionPointsCost.bConsumeAllPoints = true;
    kActionPointsCost.DoNotConsumeAllAbilities.AddItem('LightEmUp');
    Template.AbilityCosts.AddItem(kActionPointsCost);

    kAmmoCost = new class'LWCEAbilityCost_Ammo';
    kAmmoCost.iAmmo = 1;
    Template.AbilityCosts.AddItem(kAmmoCost);

	Template.AbilityTargetStyle = default.SimpleSingleTarget;
	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AbilityTargetConditions.AddItem(default.LivingHostileTargetProperty);

    kVisCondition = new class'LWCECondition_Visibility';
    kVisCondition.bRequireLineOfSight = true;
    kVisCondition.bAllowSquadsight = true;
    Template.AbilityTargetConditions.AddItem(kVisCondition);

	kEffect = new class'LWCEEffect_ApplyWeaponDamage';
	kEffect.bDealEnvironmentalDamage = true;
	kEffect.bDealUnitDamage = true;
	Template.AbilityTargetEffects.AddItem(kEffect);

	Template.AbilityToHitCalc = default.SimpleStandardAim;

    return Template;
}

defaultproperties
{
	Begin Object Class=LWCEAbilityToHitCalc_DeadEye Name=DefaultDeadEye
	End Object
	DeadEye = DefaultDeadEye;

    Begin Object Class=LWCEAbilityToHitCalc_StandardAim Name=DefaultSimpleStandardAim
        bCanCrit=true
	End Object
	SimpleStandardAim = DefaultSimpleStandardAim;

	Begin Object Class=LWCECondition_UnitProperty Name=DefaultLivingShooterProperty
		bExcludeLiving=false
		bExcludeDead=true
		bExcludeFriendlyToSource=false
		bExcludeHostileToSource=true
	End Object
	LivingShooterProperty = DefaultLivingShooterProperty;

	Begin Object Class=LWCECondition_UnitProperty Name=DefaultLivingHostileTargetProperty
		bExcludeLiving=false
		bExcludeDead=true
		bExcludeFriendlyToSource=true
		bExcludeHostileToSource=false
		bTreatMindControlledSquadmateAsHostile=true
	End Object
	LivingHostileTargetProperty = DefaultLivingHostileTargetProperty;

    Begin Object Class=LWCECondition_Visibility Name=DefaultVisibleToSourceCondition
		bRequireLineOfSight=true
		bAllowSquadsight=false
	End Object
	VisibleToSourceCondition = DefaultVisibleToSourceCondition;

    Begin Object Class=LWCEAbilityTargetStyle_Single Name=DefaultSimpleSingleTarget
	End Object
	SimpleSingleTarget = DefaultSimpleSingleTarget;

	Begin Object Class=LWCEAbilityTargetStyle_Self Name=DefaultSelfTarget
	End Object
	SelfTarget = DefaultSelfTarget;

	Begin Object Class=LWCEAbilityTrigger_UnitPostBeginPlay Name=DefaultUnitPostBeginPlayTrigger
	End Object
	UnitPostBeginPlayTrigger = DefaultUnitPostBeginPlayTrigger;
}