// Demo Data Loader for Drug_Product__c
// Run: sf apex run --file scripts/apex/create-demo-data.apex --target-org portfolio-dev
//
// Creates 22 pharmaceutical product records covering all therapeutic areas,
// regulatory statuses, dosage forms, and classification types.
// Includes real FDA-listed drugs and fictional pipeline compounds.
// Idempotent: deletes existing records first, safe to re-run.

delete [SELECT Id FROM Drug_Product__c];

List<Drug_Product__c> products = new List<Drug_Product__c>();

// ============================================================================
// GROUP 1: Real Drugs — FDA-Enriched
// Last_FDA_Sync__c populated, rich label text simulating prior OpenFDA sync
// ============================================================================

// 1. Humira (Immunology, Launched)
Drug_Product__c p1 = new Drug_Product__c();
p1.Product_Name__c = 'Humira';
p1.Generic_Name__c = 'adalimumab';
p1.NDC_Code__c = '0074-3799-02';
p1.Therapeutic_Area__c = 'Immunology';
p1.Drug_Classification__c = 'Rx';
p1.Dosage_Form__c = 'Injectable';
p1.Strength__c = '40mg/0.8mL';
p1.Manufacturer__c = 'AbbVie Inc.';
p1.Regulatory_Status__c = 'Launched';
p1.FDA_Approval_Date__c = Date.newInstance(2002, 12, 31);
p1.Launch_Date__c = Date.newInstance(2003, 1, 31);
p1.Patent_Expiration__c = Date.newInstance(2023, 1, 31);
p1.Indications__c = 'Indicated for treatment of rheumatoid arthritis, psoriatic arthritis, ankylosing spondylitis, Crohn\'s disease, ulcerative colitis, plaque psoriasis, and juvenile idiopathic arthritis in patients who have had an inadequate response to conventional therapy.';
p1.Warnings__c = 'WARNING: SERIOUS INFECTIONS AND MALIGNANCY. Increased risk of serious infections leading to hospitalization or death. Lymphoma and other malignancies have been reported in children and adolescent patients treated with TNF blockers.';
p1.Active_Ingredients__c = 'Adalimumab';
p1.Orphan_Drug_Status__c = false;
p1.Last_FDA_Sync__c = DateTime.newInstance(2026, 2, 15, 9, 30, 0);
products.add(p1);

// 2. Keytruda (Oncology, Post-Marketing)
Drug_Product__c p2 = new Drug_Product__c();
p2.Product_Name__c = 'Keytruda';
p2.Generic_Name__c = 'pembrolizumab';
p2.NDC_Code__c = '0006-3026-02';
p2.Therapeutic_Area__c = 'Oncology';
p2.Drug_Classification__c = 'Rx';
p2.Dosage_Form__c = 'Infusion';
p2.Strength__c = '100mg/4mL';
p2.Manufacturer__c = 'Merck Sharp & Dohme LLC';
p2.Regulatory_Status__c = 'Post-Marketing';
p2.FDA_Approval_Date__c = Date.newInstance(2014, 9, 4);
p2.Launch_Date__c = Date.newInstance(2014, 9, 22);
p2.Patent_Expiration__c = Date.newInstance(2028, 7, 28);
p2.Indications__c = 'Indicated for the treatment of unresectable or metastatic melanoma, non-small cell lung cancer, head and neck squamous cell carcinoma, and classical Hodgkin lymphoma in patients meeting specific biomarker criteria.';
p2.Warnings__c = 'Immune-mediated adverse reactions including pneumonitis, colitis, hepatitis, endocrinopathies, and nephritis can occur. Monitor for signs and symptoms. Withhold or permanently discontinue based on severity.';
p2.Active_Ingredients__c = 'Pembrolizumab';
p2.Orphan_Drug_Status__c = false;
p2.Last_FDA_Sync__c = DateTime.newInstance(2026, 2, 15, 9, 32, 0);
products.add(p2);

// 3. Ozempic (Endocrinology, Launched)
Drug_Product__c p3 = new Drug_Product__c();
p3.Product_Name__c = 'Ozempic';
p3.Generic_Name__c = 'semaglutide';
p3.NDC_Code__c = '0169-4132-12';
p3.Therapeutic_Area__c = 'Endocrinology';
p3.Drug_Classification__c = 'Rx';
p3.Dosage_Form__c = 'Injectable';
p3.Strength__c = '1mg/dose';
p3.Manufacturer__c = 'Novo Nordisk Inc.';
p3.Regulatory_Status__c = 'Launched';
p3.FDA_Approval_Date__c = Date.newInstance(2017, 12, 5);
p3.Launch_Date__c = Date.newInstance(2018, 2, 1);
p3.Patent_Expiration__c = Date.newInstance(2032, 3, 14);
p3.Indications__c = 'Indicated as an adjunct to diet and exercise to improve glycemic control in adults with type 2 diabetes mellitus. Also indicated to reduce the risk of major adverse cardiovascular events in adults with type 2 diabetes and established cardiovascular disease.';
p3.Warnings__c = 'WARNING: RISK OF THYROID C-CELL TUMORS. Semaglutide causes thyroid C-cell tumors in rodents. Contraindicated in patients with a personal or family history of medullary thyroid carcinoma or Multiple Endocrine Neoplasia syndrome type 2.';
p3.Active_Ingredients__c = 'Semaglutide';
p3.Orphan_Drug_Status__c = false;
p3.Last_FDA_Sync__c = DateTime.newInstance(2026, 2, 15, 9, 34, 0);
products.add(p3);

// 4. Lipitor (Cardiovascular, Discontinued)
Drug_Product__c p4 = new Drug_Product__c();
p4.Product_Name__c = 'Lipitor';
p4.Generic_Name__c = 'atorvastatin calcium';
p4.NDC_Code__c = '0071-0156-23';
p4.Therapeutic_Area__c = 'Cardiovascular';
p4.Drug_Classification__c = 'Rx';
p4.Dosage_Form__c = 'Tablet';
p4.Strength__c = '20mg';
p4.Manufacturer__c = 'Pfizer Inc.';
p4.Regulatory_Status__c = 'Discontinued';
p4.FDA_Approval_Date__c = Date.newInstance(1996, 12, 17);
p4.Launch_Date__c = Date.newInstance(1997, 1, 27);
p4.Patent_Expiration__c = Date.newInstance(2011, 11, 30);
p4.Indications__c = 'Indicated as adjunctive therapy to diet to reduce elevated total cholesterol, LDL-C, apolipoprotein B, and triglycerides in patients with primary hyperlipidemia and mixed dyslipidemia.';
p4.Warnings__c = 'Rare cases of rhabdomyolysis with acute renal failure secondary to myoglobinuria have been reported. Liver enzyme abnormalities and hepatic failure have occurred. Discontinue if serious hepatotoxicity with clinical symptoms is suspected.';
p4.Active_Ingredients__c = 'Atorvastatin calcium trihydrate';
p4.Orphan_Drug_Status__c = false;
p4.Last_FDA_Sync__c = DateTime.newInstance(2026, 2, 15, 9, 36, 0);
products.add(p4);

// 5. Xarelto (Cardiovascular, Launched)
Drug_Product__c p5 = new Drug_Product__c();
p5.Product_Name__c = 'Xarelto';
p5.Generic_Name__c = 'rivaroxaban';
p5.NDC_Code__c = '50458-0580-30';
p5.Therapeutic_Area__c = 'Cardiovascular';
p5.Drug_Classification__c = 'Rx';
p5.Dosage_Form__c = 'Tablet';
p5.Strength__c = '20mg';
p5.Manufacturer__c = 'Janssen Pharmaceuticals, Inc.';
p5.Regulatory_Status__c = 'Launched';
p5.FDA_Approval_Date__c = Date.newInstance(2011, 7, 1);
p5.Launch_Date__c = Date.newInstance(2011, 7, 15);
p5.Patent_Expiration__c = Date.newInstance(2024, 3, 28);
p5.Indications__c = 'Indicated for reduction of risk of stroke and systemic embolism in patients with nonvalvular atrial fibrillation, treatment of deep vein thrombosis and pulmonary embolism, and prophylaxis of DVT following hip or knee replacement surgery.';
p5.Warnings__c = 'WARNING: PREMATURE DISCONTINUATION AND SPINAL/EPIDURAL HEMATOMA. Premature discontinuation increases the risk of thrombotic events. Epidural or spinal hematomas may occur in patients receiving neuraxial anesthesia.';
p5.Active_Ingredients__c = 'Rivaroxaban';
p5.Orphan_Drug_Status__c = false;
p5.Last_FDA_Sync__c = DateTime.newInstance(2026, 2, 15, 9, 38, 0);
products.add(p5);

// 6. Zoloft (Neurology, Post-Marketing)
Drug_Product__c p6 = new Drug_Product__c();
p6.Product_Name__c = 'Zoloft';
p6.Generic_Name__c = 'sertraline hydrochloride';
p6.NDC_Code__c = '0049-4900-50';
p6.Therapeutic_Area__c = 'Neurology';
p6.Drug_Classification__c = 'Rx';
p6.Dosage_Form__c = 'Tablet';
p6.Strength__c = '50mg';
p6.Manufacturer__c = 'Pfizer Inc.';
p6.Regulatory_Status__c = 'Post-Marketing';
p6.FDA_Approval_Date__c = Date.newInstance(1991, 12, 30);
p6.Launch_Date__c = Date.newInstance(1992, 2, 25);
p6.Patent_Expiration__c = Date.newInstance(2006, 6, 30);
p6.Indications__c = 'Indicated for the treatment of major depressive disorder, obsessive-compulsive disorder, panic disorder, post-traumatic stress disorder, premenstrual dysphoric disorder, and social anxiety disorder in adults.';
p6.Warnings__c = 'WARNING: SUICIDALITY AND ANTIDEPRESSANT DRUGS. Antidepressants increased the risk of suicidal thinking and behavior in children, adolescents, and young adults. Monitor all patients for clinical worsening and emergence of suicidal thoughts.';
p6.Active_Ingredients__c = 'Sertraline hydrochloride';
p6.Orphan_Drug_Status__c = false;
p6.Last_FDA_Sync__c = DateTime.newInstance(2026, 2, 15, 9, 40, 0);
products.add(p6);

// ============================================================================
// GROUP 2: Real Drugs — Awaiting Enrichment
// Last_FDA_Sync__c null, sparse data — can be enriched via OpenFDA as demo
// ============================================================================

// 7. Symbicort (Respiratory, Approved)
Drug_Product__c p7 = new Drug_Product__c();
p7.Product_Name__c = 'Symbicort';
p7.Generic_Name__c = 'budesonide/formoterol';
p7.NDC_Code__c = '0186-0372-20';
p7.Therapeutic_Area__c = 'Respiratory';
p7.Drug_Classification__c = 'Rx';
p7.Dosage_Form__c = 'Inhaler';
p7.Strength__c = '160/4.5mcg';
p7.Manufacturer__c = 'AstraZeneca';
p7.Regulatory_Status__c = 'Approved';
p7.FDA_Approval_Date__c = Date.newInstance(2006, 7, 21);
p7.Orphan_Drug_Status__c = false;
products.add(p7);

// 8. Dupixent (Dermatology, Launched)
Drug_Product__c p8 = new Drug_Product__c();
p8.Product_Name__c = 'Dupixent';
p8.Generic_Name__c = 'dupilumab';
p8.NDC_Code__c = '0024-5918-01';
p8.Therapeutic_Area__c = 'Dermatology';
p8.Drug_Classification__c = 'Rx';
p8.Dosage_Form__c = 'Injectable';
p8.Strength__c = '300mg/2mL';
p8.Manufacturer__c = 'Regeneron Pharmaceuticals';
p8.Regulatory_Status__c = 'Launched';
p8.FDA_Approval_Date__c = Date.newInstance(2017, 3, 28);
p8.Launch_Date__c = Date.newInstance(2017, 4, 15);
p8.Indications__c = 'Treatment of moderate-to-severe atopic dermatitis in adults and pediatric patients.';
p8.Active_Ingredients__c = 'Dupilumab';
p8.Orphan_Drug_Status__c = false;
products.add(p8);

// ============================================================================
// GROUP 3: Fictional Pipeline Drugs — Early Stage
// No NDC codes, no FDA sync, sparse data reflecting early development
// ============================================================================

// 9. Velosinib (Oncology, In Discovery)
Drug_Product__c p9 = new Drug_Product__c();
p9.Product_Name__c = 'Velosinib';
p9.Generic_Name__c = 'velosinib';
p9.Therapeutic_Area__c = 'Oncology';
p9.Drug_Classification__c = 'Rx';
p9.Dosage_Form__c = 'Capsule';
p9.Strength__c = '50mg';
p9.Manufacturer__c = 'Aurion BioSciences';
p9.Regulatory_Status__c = 'In Discovery';
p9.Indications__c = 'Investigational selective kinase inhibitor targeting FGFR2 amplification in advanced solid tumors.';
p9.Active_Ingredients__c = 'Velosinib mesylate';
p9.Orphan_Drug_Status__c = false;
products.add(p9);

// 10. Nepruvimab (Infectious Disease, IND Pending)
Drug_Product__c p10 = new Drug_Product__c();
p10.Product_Name__c = 'Nepruvimab';
p10.Generic_Name__c = 'nepruvimab';
p10.Therapeutic_Area__c = 'Infectious Disease';
p10.Drug_Classification__c = 'Rx';
p10.Dosage_Form__c = 'Infusion';
p10.Strength__c = '500mg/50mL';
p10.Manufacturer__c = 'Crestline Therapeutics';
p10.Regulatory_Status__c = 'IND Pending';
p10.Indications__c = 'Monoclonal antibody targeting viral surface glycoprotein for treatment of severe RSV infections in immunocompromised adults.';
p10.Active_Ingredients__c = 'Nepruvimab';
p10.Orphan_Drug_Status__c = false;
products.add(p10);

// 11. Cardilozine (Cardiovascular, Phase 1)
Drug_Product__c p11 = new Drug_Product__c();
p11.Product_Name__c = 'Cardilozine';
p11.Generic_Name__c = 'cardilozine tartrate';
p11.Therapeutic_Area__c = 'Cardiovascular';
p11.Drug_Classification__c = 'Rx';
p11.Dosage_Form__c = 'Tablet';
p11.Strength__c = '10mg';
p11.Manufacturer__c = 'Helix Cardiovascular Inc.';
p11.Regulatory_Status__c = 'Phase 1';
p11.Indications__c = 'Novel calcium channel modulator under investigation for treatment-resistant hypertension in adults.';
p11.Active_Ingredients__c = 'Cardilozine tartrate';
p11.Orphan_Drug_Status__c = false;
products.add(p11);

// 12. Tremoritide (Neurology, Phase 2)
Drug_Product__c p12 = new Drug_Product__c();
p12.Product_Name__c = 'Tremoritide';
p12.Generic_Name__c = 'tremoritide acetate';
p12.Therapeutic_Area__c = 'Neurology';
p12.Drug_Classification__c = 'Rx';
p12.Dosage_Form__c = 'Patch';
p12.Strength__c = '12mg/24hr';
p12.Manufacturer__c = 'NeuroPharma Solutions';
p12.Regulatory_Status__c = 'Phase 2';
p12.Indications__c = 'Investigational peptide therapeutic for reduction of essential tremor severity via sustained transdermal delivery.';
p12.Active_Ingredients__c = 'Tremoritide acetate';
p12.Orphan_Drug_Status__c = false;
products.add(p12);

// 13. Gutanavir (Gastroenterology, Phase 3)
Drug_Product__c p13 = new Drug_Product__c();
p13.Product_Name__c = 'Gutanavir';
p13.Generic_Name__c = 'gutanavir sodium';
p13.Therapeutic_Area__c = 'Gastroenterology';
p13.Drug_Classification__c = 'Rx';
p13.Dosage_Form__c = 'Capsule';
p13.Strength__c = '200mg';
p13.Manufacturer__c = 'Meridian Gastro Labs';
p13.Regulatory_Status__c = 'Phase 3';
p13.Indications__c = 'Protease inhibitor under investigation for treatment of refractory Clostridioides difficile infection in hospitalized patients.';
p13.Active_Ingredients__c = 'Gutanavir sodium';
p13.Orphan_Drug_Status__c = false;
products.add(p13);

// ============================================================================
// GROUP 4: Fictional Drugs — Late Stage / Regulatory
// ============================================================================

// 14. Pulmonex (Respiratory, NDA Submitted)
Drug_Product__c p14 = new Drug_Product__c();
p14.Product_Name__c = 'Pulmonex';
p14.Generic_Name__c = 'brontolizumab';
p14.Therapeutic_Area__c = 'Respiratory';
p14.Drug_Classification__c = 'Rx';
p14.Dosage_Form__c = 'Injectable';
p14.Strength__c = '200mg/mL';
p14.Manufacturer__c = 'Ventus Biotherapeutics';
p14.Regulatory_Status__c = 'NDA Submitted';
p14.Indications__c = 'Anti-IL-33 monoclonal antibody for severe eosinophilic asthma in adults uncontrolled on high-dose inhaled corticosteroids plus LABA therapy.';
p14.Active_Ingredients__c = 'Brontolizumab';
p14.Orphan_Drug_Status__c = false;
products.add(p14);

// 15. Dermaclyn (Dermatology, Under FDA Review)
Drug_Product__c p15 = new Drug_Product__c();
p15.Product_Name__c = 'Dermaclyn';
p15.Generic_Name__c = 'clobefirate';
p15.Therapeutic_Area__c = 'Dermatology';
p15.Drug_Classification__c = 'Rx';
p15.Dosage_Form__c = 'Topical';
p15.Strength__c = '0.05%';
p15.Manufacturer__c = 'Solaris Dermatologics';
p15.Regulatory_Status__c = 'Under FDA Review';
p15.Indications__c = 'Topical retinoid derivative for moderate-to-severe chronic plaque psoriasis in adults who are candidates for systemic therapy.';
p15.Active_Ingredients__c = 'Clobefirate';
p15.Orphan_Drug_Status__c = false;
products.add(p15);

// 16. Glucaferrin (Endocrinology, Approved — RULE ENGINE DEMO TARGET)
Drug_Product__c p16 = new Drug_Product__c();
p16.Product_Name__c = 'Glucaferrin';
p16.Generic_Name__c = 'tresoglitazar';
p16.NDC_Code__c = '72845-0101-30';
p16.Therapeutic_Area__c = 'Endocrinology';
p16.Drug_Classification__c = 'Rx';
p16.Dosage_Form__c = 'Tablet';
p16.Strength__c = '15mg';
p16.Manufacturer__c = 'Pinnacle Metabolics';
p16.Regulatory_Status__c = 'Approved';
p16.FDA_Approval_Date__c = Date.newInstance(2025, 8, 12);
p16.Patent_Expiration__c = Date.newInstance(2041, 8, 12);
p16.Indications__c = 'Dual PPAR agonist indicated for improvement of glycemic control in adults with type 2 diabetes mellitus who have not achieved adequate control with metformin monotherapy.';
p16.Warnings__c = 'May cause fluid retention and peripheral edema. Monitor patients for signs of congestive heart failure. Contraindicated in patients with NYHA Class III or IV heart failure.';
p16.Active_Ingredients__c = 'Tresoglitazar';
p16.Orphan_Drug_Status__c = false;
products.add(p16);

// 17. Immunex-4 (Immunology, Approved — RULE ENGINE DEMO TARGET)
Drug_Product__c p17 = new Drug_Product__c();
p17.Product_Name__c = 'Immunex-4';
p17.Generic_Name__c = 'sarilonimab';
p17.NDC_Code__c = '72845-0204-01';
p17.Therapeutic_Area__c = 'Immunology';
p17.Drug_Classification__c = 'Rx';
p17.Dosage_Form__c = 'Injectable';
p17.Strength__c = '150mg/mL';
p17.Manufacturer__c = 'Crestline Therapeutics';
p17.Regulatory_Status__c = 'Approved';
p17.FDA_Approval_Date__c = Date.newInstance(2025, 11, 3);
p17.Patent_Expiration__c = Date.newInstance(2042, 5, 15);
p17.Indications__c = 'IL-4 receptor antagonist indicated for treatment of moderate-to-severe rheumatoid arthritis in adults with inadequate response to one or more DMARDs.';
p17.Warnings__c = 'Serious infections including tuberculosis, invasive fungal infections, and opportunistic infections have occurred. Test for latent TB prior to initiating therapy.';
p17.Active_Ingredients__c = 'Sarilonimab';
p17.Orphan_Drug_Status__c = false;
products.add(p17);

// ============================================================================
// GROUP 5: Special Cases
// Controlled Substance, Orphan Drugs, OTC, varied dosage forms
// ============================================================================

// 18. Oxycodone XR (Neurology, Launched — CONTROLLED SUBSTANCE)
Drug_Product__c p18 = new Drug_Product__c();
p18.Product_Name__c = 'Oxycodone XR';
p18.Generic_Name__c = 'oxycodone hydrochloride';
p18.NDC_Code__c = '59011-0442-20';
p18.Therapeutic_Area__c = 'Neurology';
p18.Drug_Classification__c = 'Controlled Substance';
p18.Dosage_Form__c = 'Tablet';
p18.Strength__c = '10mg';
p18.Manufacturer__c = 'Purdue Pharma L.P.';
p18.Regulatory_Status__c = 'Launched';
p18.FDA_Approval_Date__c = Date.newInstance(2010, 4, 5);
p18.Launch_Date__c = Date.newInstance(2010, 8, 9);
p18.Patent_Expiration__c = Date.newInstance(2025, 6, 30);
p18.Indications__c = 'Indicated for the management of pain severe enough to require daily, around-the-clock, long-term opioid treatment and for which alternative treatment options are inadequate.';
p18.Warnings__c = 'WARNING: ADDICTION, ABUSE, AND MISUSE; LIFE-THREATENING RESPIRATORY DEPRESSION. Schedule II controlled substance with high potential for abuse and addiction. Serious, life-threatening respiratory depression may occur. Prolonged use during pregnancy can result in neonatal opioid withdrawal syndrome.';
p18.Active_Ingredients__c = 'Oxycodone hydrochloride';
p18.Orphan_Drug_Status__c = false;
p18.Last_FDA_Sync__c = DateTime.newInstance(2026, 2, 15, 9, 42, 0);
products.add(p18);

// 19. Rarituxan (Rare Disease, Launched — ORPHAN DRUG)
Drug_Product__c p19 = new Drug_Product__c();
p19.Product_Name__c = 'Rarituxan';
p19.Generic_Name__c = 'fenolizumab';
p19.NDC_Code__c = '72845-0310-01';
p19.Therapeutic_Area__c = 'Rare Disease';
p19.Drug_Classification__c = 'Rx';
p19.Dosage_Form__c = 'Infusion';
p19.Strength__c = '10mg/mL';
p19.Manufacturer__c = 'Orphan Therapeutics Inc.';
p19.Regulatory_Status__c = 'Launched';
p19.FDA_Approval_Date__c = Date.newInstance(2024, 6, 18);
p19.Launch_Date__c = Date.newInstance(2024, 9, 1);
p19.Patent_Expiration__c = Date.newInstance(2041, 6, 18);
p19.Indications__c = 'Indicated for treatment of adult patients with paroxysmal nocturnal hemoglobinuria (PNH) who have an inadequate response to complement inhibitor therapy. Granted Orphan Drug designation.';
p19.Warnings__c = 'Serious meningococcal infections have occurred. Vaccinate patients against meningococcal infection at least 2 weeks prior to first dose. Monitor for early signs of meningococcal infection.';
p19.Active_Ingredients__c = 'Fenolizumab';
p19.Orphan_Drug_Status__c = true;
products.add(p19);

// 20. ClearHist-D (Immunology, Launched — OTC)
Drug_Product__c p20 = new Drug_Product__c();
p20.Product_Name__c = 'ClearHist-D';
p20.Generic_Name__c = 'loratadine/pseudoephedrine';
p20.NDC_Code__c = '11523-7342-01';
p20.Therapeutic_Area__c = 'Immunology';
p20.Drug_Classification__c = 'OTC';
p20.Dosage_Form__c = 'Tablet';
p20.Strength__c = '10mg/240mg';
p20.Manufacturer__c = 'Apex Consumer Health';
p20.Regulatory_Status__c = 'Launched';
p20.FDA_Approval_Date__c = Date.newInstance(2019, 3, 15);
p20.Launch_Date__c = Date.newInstance(2019, 5, 1);
p20.Indications__c = 'For temporary relief of symptoms due to hay fever or other upper respiratory allergies: runny nose, sneezing, itchy/watery eyes, nasal congestion, and sinus pressure.';
p20.Active_Ingredients__c = 'Loratadine; Pseudoephedrine sulfate';
p20.Orphan_Drug_Status__c = false;
products.add(p20);

// 21. Gastrex (Gastroenterology, Approved — RULE ENGINE DEMO TARGET)
Drug_Product__c p21 = new Drug_Product__c();
p21.Product_Name__c = 'Gastrex';
p21.Generic_Name__c = 'vonalesiran';
p21.NDC_Code__c = '72845-0415-16';
p21.Therapeutic_Area__c = 'Gastroenterology';
p21.Drug_Classification__c = 'Rx';
p21.Dosage_Form__c = 'Oral Solution';
p21.Strength__c = '40mg/5mL';
p21.Manufacturer__c = 'Meridian Gastro Labs';
p21.Regulatory_Status__c = 'Approved';
p21.FDA_Approval_Date__c = Date.newInstance(2025, 5, 20);
p21.Patent_Expiration__c = Date.newInstance(2042, 5, 20);
p21.Indications__c = 'Indicated for treatment of short bowel syndrome in adult patients who are dependent on parenteral nutrition.';
p21.Warnings__c = 'Risk of intestinal obstruction and gallbladder-related events including cholecystitis and cholelithiasis. Monitor with periodic abdominal imaging.';
p21.Active_Ingredients__c = 'Vonalesiran';
p21.Orphan_Drug_Status__c = false;
products.add(p21);

// 22. Raregen (Rare Disease, Phase 2 — ORPHAN DRUG, early pipeline)
Drug_Product__c p22 = new Drug_Product__c();
p22.Product_Name__c = 'Raregen';
p22.Generic_Name__c = 'fazimostat';
p22.Therapeutic_Area__c = 'Rare Disease';
p22.Drug_Classification__c = 'Rx';
p22.Dosage_Form__c = 'Capsule';
p22.Strength__c = '25mg';
p22.Manufacturer__c = 'Orphan Therapeutics Inc.';
p22.Regulatory_Status__c = 'Phase 2';
p22.Indications__c = 'Investigational enzyme replacement therapy for Fabry disease. Phase 2 trial evaluating safety and efficacy of oral substrate reduction therapy.';
p22.Active_Ingredients__c = 'Fazimostat dihydrochloride';
p22.Orphan_Drug_Status__c = true;
products.add(p22);

// ============================================================================
// INSERT ALL RECORDS
// ============================================================================

insert products;
System.debug('Successfully inserted ' + products.size() + ' Drug Product demo records.');
