import 'package:flutter/material.dart';

import '../../PurchaseOrder/services/theme.dart';

// ══════════════════════════════════════════════════════════════
//  SKILL & PERFORMANCE QUESTIONNAIRE (mobile)
//
//  Mirrors the web onboarding form / backend Employee.skillProfile:
//  experience, knotting performance, machine production performance,
//  the 10-skill knowledge grid (not_known/basic/good/expert) and the
//  supervisor's 1–5 ratings. State lives in SkillProfileData so the
//  parent page can serialise it with toJson() on submit.
// ══════════════════════════════════════════════════════════════

const List<MapEntry<String, String>> kSkillKeys = [
  MapEntry('drawing', 'Drawing'),
  MapEntry('knotting', 'Knotting'),
  MapEntry('tapeSetting', 'Tape setting'),
  MapEntry('chainLinkSetting', 'Chain link setting'),
  MapEntry('chainDesign', 'Chain design'),
  MapEntry('jacquardHookModule', 'Jacquard hook (module)'),
  MapEntry('jacquardHookKarampal', 'Jacquard hook (karampal)'),
  MapEntry('timingBeltChange', 'Timing belt change'),
  MapEntry('timingSetting', 'Timing setting'),
  MapEntry('machineRepair', 'Machine repair'),
];

const List<String> kSkillLevels = ['not_known', 'basic', 'good', 'expert'];
const Map<String, String> kLevelShort = {
  'not_known': 'N/K', 'basic': 'Basic', 'good': 'Good', 'expert': 'Expert',
};

class SkillProfileData {
  String machineType = '';
  double? yearsOfExperience;
  double? time100YarnsMin;
  String knottingQuality = '';
  double? maxYarnsAtOnce;
  double? minPerShift;
  double? avgEfficiencyPct;
  double? machinesSimultaneous;
  final Map<String, String> skills = {
    for (final e in kSkillKeys) e.key: 'not_known',
  };
  int? supSkill, supEfficiency, supProblem, supDiscipline;

  Map<String, dynamic> toJson() => {
        'machineType': machineType,
        if (yearsOfExperience != null) 'yearsOfExperience': yearsOfExperience,
        'knotting': {
          if (time100YarnsMin != null) 'time100YarnsMin': time100YarnsMin,
          'quality': knottingQuality,
          if (maxYarnsAtOnce != null) 'maxYarnsAtOnce': maxYarnsAtOnce,
        },
        'production': {
          if (minPerShift != null) 'minPerShift': minPerShift,
          if (avgEfficiencyPct != null) 'avgEfficiencyPct': avgEfficiencyPct,
          if (machinesSimultaneous != null) 'machinesSimultaneous': machinesSimultaneous,
        },
        'skills': skills,
        'supervisor': {
          if (supSkill != null) 'skillLevel': supSkill,
          if (supEfficiency != null) 'machineEfficiency': supEfficiency,
          if (supProblem != null) 'problemSolving': supProblem,
          if (supDiscipline != null) 'discipline': supDiscipline,
        },
      };
}

class SkillQuestionnaireSection extends StatefulWidget {
  final SkillProfileData data;
  const SkillQuestionnaireSection({super.key, required this.data});

  @override
  State<SkillQuestionnaireSection> createState() => _SkillQuestionnaireSectionState();
}

class _SkillQuestionnaireSectionState extends State<SkillQuestionnaireSection> {
  SkillProfileData get d => widget.data;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ErpSectionCard(
        title: 'EXPERIENCE',
        icon: Icons.timeline_rounded,
        child: Column(children: [
          _numText('Machine type (e.g. jacquard)', text: true,
              initial: d.machineType, onChanged: (v) => d.machineType = v),
          const SizedBox(height: 12),
          _numText('Years of experience',
              onNum: (v) => d.yearsOfExperience = v),
        ]),
      ),
      const SizedBox(height: 12),
      ErpSectionCard(
        title: 'KNOTTING PERFORMANCE',
        icon: Icons.gesture_rounded,
        child: Column(children: [
          _numText('Minutes to knot 100 yarns', onNum: (v) => d.time100YarnsMin = v),
          const SizedBox(height: 12),
          _levelPicker(
            label: 'Knotting quality',
            values: const ['', 'poor', 'average', 'good', 'excellent'],
            labels: const ['—', 'Poor', 'Avg', 'Good', 'Excellent'],
            selected: d.knottingQuality,
            onSelected: (v) => setState(() => d.knottingQuality = v),
          ),
          const SizedBox(height: 12),
          _numText('Max yarns at one time', onNum: (v) => d.maxYarnsAtOnce = v),
        ]),
      ),
      const SizedBox(height: 12),
      ErpSectionCard(
        title: 'MACHINE PRODUCTION PERFORMANCE',
        icon: Icons.precision_manufacturing_outlined,
        child: Column(children: [
          _numText('Min assured production / shift (m or kg)', onNum: (v) => d.minPerShift = v),
          const SizedBox(height: 12),
          _numText('Average machine efficiency (%)', onNum: (v) => d.avgEfficiencyPct = v),
          const SizedBox(height: 12),
          _numText('Machines handled simultaneously', onNum: (v) => d.machinesSimultaneous = v),
        ]),
      ),
      const SizedBox(height: 12),
      ErpSectionCard(
        title: 'SKILL KNOWLEDGE',
        icon: Icons.school_outlined,
        child: Column(
          children: kSkillKeys.map((e) {
            final current = d.skills[e.key] ?? 'not_known';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.value,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: ErpColors.textPrimary)),
                  const SizedBox(height: 6),
                  Row(
                    children: kSkillLevels.map((lvl) {
                      final selected = current == lvl;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(kLevelShort[lvl]!,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? Colors.white : ErpColors.textSecondary)),
                          selected: selected,
                          selectedColor: ErpColors.accentBlue,
                          backgroundColor: ErpColors.bgMuted,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => setState(() => d.skills[e.key] = lvl),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 12),
      ErpSectionCard(
        title: 'SUPERVISOR EVALUATION (1–5)',
        icon: Icons.grade_outlined,
        child: Column(children: [
          Row(children: [
            Expanded(child: _ratingDropdown('Skill level', d.supSkill, (v) => setState(() => d.supSkill = v))),
            const SizedBox(width: 10),
            Expanded(child: _ratingDropdown('Machine efficiency', d.supEfficiency, (v) => setState(() => d.supEfficiency = v))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _ratingDropdown('Problem solving', d.supProblem, (v) => setState(() => d.supProblem = v))),
            const SizedBox(width: 10),
            Expanded(child: _ratingDropdown('Discipline', d.supDiscipline, (v) => setState(() => d.supDiscipline = v))),
          ]),
        ]),
      ),
    ]);
  }

  Widget _numText(String label,
      {bool text = false, String initial = '', void Function(String)? onChanged, void Function(double?)? onNum}) {
    return TextFormField(
      initialValue: initial,
      keyboardType: text ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
      style: ErpTextStyles.fieldValue,
      decoration: ErpDecorations.formInput(label),
      onChanged: (v) {
        if (onChanged != null) onChanged(v);
        if (onNum != null) onNum(double.tryParse(v.trim()));
      },
    );
  }

  Widget _levelPicker({
    required String label,
    required List<String> values,
    required List<String> labels,
    required String selected,
    required void Function(String) onSelected,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: ErpColors.textPrimary)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        children: List.generate(values.length, (i) {
          final sel = selected == values[i];
          return ChoiceChip(
            label: Text(labels[i],
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : ErpColors.textSecondary)),
            selected: sel,
            selectedColor: ErpColors.accentBlue,
            backgroundColor: ErpColors.bgMuted,
            visualDensity: VisualDensity.compact,
            onSelected: (_) => onSelected(values[i]),
          );
        }),
      ),
    ]);
  }

  Widget _ratingDropdown(String label, int? value, void Function(int?) onChanged) {
    return DropdownButtonFormField<int>(
      value: value,
      isExpanded: true,
      style: ErpTextStyles.fieldValue,
      decoration: ErpDecorations.formInput(label),
      hint: const Text('—', style: TextStyle(color: ErpColors.textMuted, fontSize: 12)),
      items: [1, 2, 3, 4, 5]
          .map((n) => DropdownMenuItem(
              value: n,
              child: Text('$n',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: ErpColors.textPrimary))))
          .toList(),
      onChanged: onChanged,
    );
  }
}
