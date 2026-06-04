#!/usr/bin/env python3
from __future__ import annotations

import html
import os
import shutil
import tempfile
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "soutenance_cloud_data_platform_eqdom.pptx"

W, H = 12_192_000, 6_858_000

RED = "E31937"
BURGUNDY = "000080"
YELLOW = "FF6600"
GOLD = "F19D19"
CREAM = "FFFFFF"
INK = "222222"
MUTED = "595959"
WHITE = "FFFFFF"
LIGHT = "F5F5F5"
GREEN = "4C7EB8"
BLUE = "4C7EB8"
ORANGE = "FF6600"
NAVY = "000080"
TEAL = "E31937"
PALE_TEAL = "F5F5F5"
PALE_GOLD = "FFF3EA"
LINE = "D2D2D2"

AXES = [
    ("01", "Contexte"),
    ("02", "Besoins"),
    ("03", "Conception"),
    ("04", "Réalisation"),
    ("05", "Valeur"),
    ("06", "Perspectives"),
]

SECTION_ALIASES = {
    "Problème": "Contexte",
    "Synthèse": "Valeur",
}


def emu(v: float) -> int:
    return int(v * 914_400)


def esc(s: str) -> str:
    return html.escape(s, quote=True)


def p_xml(
    text: str = "",
    size: int = 22,
    color: str = INK,
    bold: bool = False,
    level: int = 0,
    bullet: bool = False,
    align: str | None = None,
) -> str:
    props = []
    if align:
        props.append(f'algn="{align}"')
    if bullet:
        mar_l = 285_750 + level * 228_600
        indent = -171_450
        ppr = f'<a:pPr {" ".join(props)} marL="{mar_l}" indent="{indent}"><a:buChar char="•"/></a:pPr>'
    elif props:
        ppr = f'<a:pPr {" ".join(props)}/>'
    else:
        ppr = "<a:pPr/>"
    b = "1" if bold else "0"
    return (
        f"<a:p>{ppr}<a:r><a:rPr lang=\"fr-FR\" sz=\"{size*100}\" b=\"{b}\">"
        f"<a:solidFill><a:srgbClr val=\"{color}\"/></a:solidFill></a:rPr>"
        f"<a:t>{esc(text)}</a:t></a:r></a:p>"
    )


def tx_box(
    idx: int,
    x: float,
    y: float,
    cx: float,
    cy: float,
    paragraphs: list[str],
    fill: str | None = None,
    line: str | None = None,
    radius: str = "rect",
    margin: int = 91_440,
) -> str:
    sppr_fill = "<a:noFill/>" if fill is None else f'<a:solidFill><a:srgbClr val="{fill}"/></a:solidFill>'
    sppr_line = "<a:ln><a:noFill/></a:ln>" if line is None else f'<a:ln w="12700"><a:solidFill><a:srgbClr val="{line}"/></a:solidFill></a:ln>'
    return f"""
    <p:sp>
      <p:nvSpPr><p:cNvPr id="{idx}" name="Text {idx}"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>
      <p:spPr>
        <a:xfrm><a:off x="{emu(x)}" y="{emu(y)}"/><a:ext cx="{emu(cx)}" cy="{emu(cy)}"/></a:xfrm>
        <a:prstGeom prst="{radius}"><a:avLst/></a:prstGeom>{sppr_fill}{sppr_line}
      </p:spPr>
      <p:txBody><a:bodyPr wrap="square" lIns="{margin}" tIns="{margin}" rIns="{margin}" bIns="{margin}"/><a:lstStyle/>
        {''.join(paragraphs)}
      </p:txBody>
    </p:sp>"""


def shape(idx: int, x: float, y: float, cx: float, cy: float, fill: str, geom: str = "rect", line: str | None = None) -> str:
    ln = '<a:ln><a:noFill/></a:ln>' if line is None else f'<a:ln w="12700"><a:solidFill><a:srgbClr val="{line}"/></a:solidFill></a:ln>'
    return f"""
    <p:sp>
      <p:nvSpPr><p:cNvPr id="{idx}" name="Shape {idx}"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
      <p:spPr>
        <a:xfrm><a:off x="{emu(x)}" y="{emu(y)}"/><a:ext cx="{emu(cx)}" cy="{emu(cy)}"/></a:xfrm>
        <a:prstGeom prst="{geom}"><a:avLst/></a:prstGeom>
        <a:solidFill><a:srgbClr val="{fill}"/></a:solidFill>{ln}
      </p:spPr>
      <p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody>
    </p:sp>"""


def image_xml(idx: int, rid: str, x: float, y: float, cx: float, cy: float) -> str:
    return f"""
    <p:pic>
      <p:nvPicPr><p:cNvPr id="{idx}" name="Image {idx}"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>
      <p:blipFill><a:blip r:embed="{rid}"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>
      <p:spPr><a:xfrm><a:off x="{emu(x)}" y="{emu(y)}"/><a:ext cx="{emu(cx)}" cy="{emu(cy)}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr>
    </p:pic>"""


class Slide:
    def __init__(self, title: str, subtitle: str = "", section: str = ""):
        self.title = title
        self.subtitle = subtitle
        self.section = section
        self.elems: list[str] = []
        self.images: list[Path] = []
        self.idx = 10

    def next(self) -> int:
        self.idx += 1
        return self.idx

    def add_text(self, x, y, cx, cy, paragraphs, fill=None, line=None, radius="rect", margin=91_440):
        self.elems.append(tx_box(self.next(), x, y, cx, cy, paragraphs, fill, line, radius, margin))

    def add_shape(self, x, y, cx, cy, fill, geom="rect", line=None):
        self.elems.append(shape(self.next(), x, y, cx, cy, fill, geom, line))

    def add_image(self, path: str, x, y, cx, cy):
        self.images.append(ROOT / path)
        self.elems.append(("IMAGE", len(self.images), x, y, cx, cy, self.next()))


def add_axis_navigation(s: Slide, active_section: str, dark: bool = False) -> None:
    active_section = SECTION_ALIASES.get(active_section, active_section)
    inactive = MUTED
    widths = [1.68, 1.45, 1.72, 1.72, 1.28, 1.85]
    for i, (number, label) in enumerate(AXES):
        x = 0.38 + sum(widths[:i])
        active = label == active_section
        color = RED if active else inactive
        if active:
            s.add_shape(x, 1.00, 0.14, 0.14, RED, geom="ellipse")
        s.add_text(
            x + 0.19,
            0.98,
            widths[i] - 0.2,
            0.23,
            [p_xml(label, 9, color, active)],
            margin=4_000,
        )


def section_slide(title: str, kicker: str, bullets: list[str], section: str, transition: str) -> Slide:
    s = Slide(title, kicker, section)
    s.add_shape(0, 0, 13.33, 7.5, WHITE)
    s.add_shape(5.35, 2.62, 2.62, 0.16, RED, geom="roundRect")
    s.add_shape(5.35, 4.34, 2.62, 0.16, RED, geom="roundRect")
    s.add_text(1.6, 3.05, 10.0, 0.92, [p_xml(title, 34, INK, False, align="ctr")], margin=5_000)
    s.add_text(3.0, 4.82, 7.35, 0.44, [p_xml(transition, 12, MUTED, False, align="ctr")], margin=5_000)
    return s


def base_slide(title: str, subtitle: str = "", section: str = "") -> Slide:
    s = Slide(title, subtitle, section)
    s.add_shape(0, 0, 13.33, 7.5, WHITE)
    title_paras = [p_xml(title, 24, INK, True)]
    if subtitle:
        title_paras.append(p_xml(subtitle, 13, MUTED, False))
    s.add_text(0.45, 0.30, 11.8, 0.72, title_paras)
    if section:
        active = SECTION_ALIASES.get(section, section)
        add_axis_navigation(s, active)
    return s


def title_slide() -> Slide:
    s = Slide("Conception et déploiement d'une Cloud Data Platform", "Architecture Lakehouse sur AWS EKS")
    s.add_shape(0, 0, 13.33, 7.5, WHITE)
    s.add_shape(0, 1.85, 13.33, 1.95, RED)
    s.add_image("rapport/images/logo-ensas.png", 0.46, 0.24, 2.35, 0.55)
    s.add_image("rapport/images/seven-logo.jpg", 10.7, 0.22, 0.66, 0.66)
    s.add_image("rapport/images/eqdom-logo.png", 11.62, 0.22, 0.66, 0.66)
    s.add_text(2.72, 0.18, 7.9, 1.28, [
        p_xml("Soutenance du Projet de Fin d'Études", 20, BURGUNDY, True, align="ctr"),
        p_xml("Filière : Ingénierie des Données et Intelligence Artificielle", 14, INK, True, align="ctr"),
        p_xml("En vue de l'obtention du Diplôme d'Ingénieur d'État", 12, MUTED, False, align="ctr"),
    ], margin=5_000)
    s.add_text(0.55, 2.16, 12.22, 1.3, [
        p_xml("Conception et déploiement d'une Cloud Data Platform", 27, WHITE, True, align="ctr"),
        p_xml("Architecture Lakehouse cloud-native pour EQDOM", 18, WHITE, False, align="ctr"),
    ], margin=5_000)
    s.add_text(0.48, 4.14, 2.55, 1.16, [
        p_xml("Présenté par :", 13, BURGUNDY, True),
        p_xml("M. DAHIRY Mohammed", 15, INK, True),
        p_xml("Effectué à : SEVENAPP", 11, MUTED),
        p_xml("Mission client : EQDOM", 11, MUTED),
    ], margin=5_000)
    s.add_text(3.33, 4.14, 3.0, 1.34, [
        p_xml("Encadré par :", 13, BURGUNDY, True),
        p_xml("Pr. EZZAHAR Jamal", 13, INK, True),
        p_xml("Encadrant académique", 10, MUTED),
        p_xml("M. EL GHALLAOUI Zine Labidine", 13, INK, True),
        p_xml("Encadrant professionnel", 10, MUTED),
    ], margin=5_000)
    s.add_text(6.74, 4.14, 5.9, 1.52, [
        p_xml("Membres du jury :", 13, BURGUNDY, True),
        p_xml("Pr. EZZAHAR Jamal", 12, INK, True),
        p_xml("Pr. MADIAFI Mohammed", 12, INK, True),
        p_xml("Pr. HARZALLA Driss", 12, INK, True),
        p_xml("Pr. BENDAIDA Fatiha", 12, INK, True),
    ], margin=5_000)
    s.add_text(4.9, 6.78, 3.55, 0.3, [p_xml("Soutenu le 26 Juin 2026", 12, INK, True, align="ctr")], margin=3_000)
    return s


def add_three_cards(s: Slide, cards: list[tuple[str, str, str]], y=1.55):
    xs = [0.65, 4.65, 8.65]
    for i, (h, body, color) in enumerate(cards):
        s.add_text(xs[i], y, 3.55, 2.0, [p_xml(h, 18, color, True), p_xml(body, 14, INK)], fill=WHITE, line=LINE, radius="roundRect")


def deck() -> list[Slide]:
    slides: list[Slide] = [title_slide()]

    s = base_slide("PLAN", "")
    agenda = [
        ("01", "Contexte", "EQDOM, enjeux data et problématique"),
        ("02", "Besoins", "Exigences cloud et chaîne de confiance"),
        ("03", "Conception", "Architecture cible et choix structurants"),
        ("04", "Réalisation", "Déploiement, pipeline et preuves"),
        ("05", "Valeur", "Apports et décisions défendables"),
        ("06", "Perspectives", "Limites et trajectoire d'industrialisation"),
    ]
    for i, (number, title, detail) in enumerate(agenda):
        x = 1.38 + (i % 2) * 5.75
        y = 1.45 + (i // 2) * 1.62
        s.add_text(x, y, 0.72, 0.72, [p_xml(number, 19, RED, True, align="ctr")], line=RED, radius="ellipse", margin=7_000)
        s.add_text(x + 0.92, y - 0.02, 4.25, 0.82, [p_xml(title, 17, INK, True), p_xml(detail, 11, MUTED)], margin=5_000)
    slides.append(s)

    slides.append(section_slide("Contexte et problématique", "Axe 01 · Point de départ", [
        "Comprendre le rôle de la donnée dans le pilotage d'EQDOM.",
        "Identifier les limites du fonctionnement actuel.",
        "Formuler la question centrale à laquelle répond la plateforme.",
    ], "Contexte", "Avant de présenter la solution, il faut clarifier le terrain métier et la difficulté à résoudre."))

    s = base_slide("Contexte business EQDOM", "La data devient un levier de pilotage, de risque et d'IA", "Contexte")
    add_three_cards(s, [
        ("Ambition 2025", "Placer l'exploitation de la donnée au cœur de la transformation digitale : pilotage, IA, personnalisation et anticipation du risque.", BURGUNDY),
        ("Douleur actuelle", "Données dispersées, extractions manuelles, Power BI alimenté artisanalement, peu de standardisation et de traçabilité.", RED),
        ("Cible entreprise", "Un socle data gouverné, fiable, scalable, connecté aux métiers et prêt pour les cas d'usage analytics / data science.", GOLD),
    ])
    s.add_image("rapport/images/eqdom-logo.png", 5.95, 4.15, 1.15, 1.15)
    s.add_text(1.2, 5.25, 10.9, 0.8, [p_xml("Message jury : le projet ne vend pas de la technologie, il réduit le délai entre une donnée opérationnelle et une décision métier fiable.", 18, BURGUNDY, True, align="ctr")], fill=LIGHT, line=LINE, radius="roundRect")
    slides.append(s)

    s = base_slide("Problématique", "Industrialiser une plateforme data sans enfermer EQDOM dans un fournisseur", "Problème")
    s.add_text(0.8, 1.45, 5.7, 4.7, [
        p_xml("Constats", 20, BURGUNDY, True),
        p_xml("Sources multiples : PostgreSQL ONE, Informix CBS, SmartStream, CSV/XLS/XLSX.", 16, INK, bullet=True),
        p_xml("Transformations peu versionnées et difficilement rejouables.", 16, INK, bullet=True),
        p_xml("Incidents difficiles à diagnostiquer sans logs et métriques centralisés.", 16, INK, bullet=True),
        p_xml("Besoin d'un MVP crédible, mais extensible vers DEV / UAT / PROD.", 16, INK, bullet=True),
    ], fill=WHITE, line=LINE, radius="roundRect")
    s.add_text(6.85, 1.45, 5.65, 4.7, [
        p_xml("Question centrale", 20, RED, True),
        p_xml("Comment concevoir une Cloud Data Platform cloud-native, sécurisée et reproductible, capable d'ingérer batch et streaming, de produire un Lakehouse Bronze / Silver / Gold et d'exposer des données fiables aux usages BI et IA ?", 21, INK, True),
    ], fill=PALE_GOLD, line=YELLOW, radius="roundRect")
    slides.append(s)

    slides.append(section_slide("Analyse des besoins", "Axe 02 · Deux lectures complémentaires", [
        "Infrastructure cloud : sécurité, coûts, exposition, portabilité, exploitation.",
        "Pipeline data / DataOps : ingestion, qualité, orchestration, traçabilité, serving BI.",
        "Objectif : relier chaque exigence à un choix défendable devant le jury.",
    ], "Besoins", "Le contexte est posé. Il faut maintenant traduire les enjeux métier en exigences vérifiables."))

    s = base_slide("Analyse des besoins — Infrastructure cloud", "Ce que la plateforme doit garantir avant même de traiter la donnée", "Besoins")
    add_three_cards(s, [
        ("Sécurité", "Moindre privilège, chiffrement KMS, secrets hors Git, API EKS restreinte, exposition sans LoadBalancer public.", BURGUNDY),
        ("Coûts", "Dev dimensionné, NAT unique en MVP, compute scalable à zéro et destruction automatisée pour éviter les coûts dormants.", RED),
        ("Portabilité", "Kubernetes + MinIO + Iceberg : une architecture cloud-ready et plus simple à déplacer vers d'autres clouds ou on-prem.", GOLD),
    ])
    s.add_text(0.9, 4.25, 11.5, 1.35, [
        p_xml("Argument business", 19, BURGUNDY, True),
        p_xml("Le socle cloud doit être contrôlable financièrement et auditable techniquement : le jury doit voir une plateforme pilotable, pas un simple cluster lancé pour la démonstration.", 17, INK),
    ], fill=LIGHT, line=LINE, radius="roundRect")
    slides.append(s)

    s = base_slide("Analyse des besoins — Pipeline data / DataOps", "Transformer des sources dispersées en indicateurs consommables", "Besoins")
    add_three_cards(s, [
        ("Ingestion", "CDC pour bases opérationnelles et batch pour fichiers métier : couvrir les flux récurrents et les exports ponctuels.", BURGUNDY),
        ("Qualité", "Bronze pour l'historique brut, Silver pour le nettoyage, Gold pour les indicateurs métier validés.", RED),
        ("DataOps", "DAGs Airflow, jobs Spark/dbt versionnés, logs, métriques et capacité de rejeu.", GOLD),
    ])
    s.add_text(0.9, 4.25, 11.5, 1.35, [
        p_xml("Argument business", 19, BURGUNDY, True),
        p_xml("Le pipeline ne sert pas seulement à déplacer des données : il crée une chaîne de confiance entre les sources opérationnelles et les décisions de pilotage.", 17, INK),
    ], fill=LIGHT, line=LINE, radius="roundRect")
    slides.append(s)

    slides.append(section_slide("Conception de la solution", "Axe 03 · Choix d'architecture", [
        "Infrastructure cloud : landing zone EKS, stockage persistant, exposition Zero Trust et scheduling de coût.",
        "Pipeline data : Lakehouse médaillon, orchestration Airflow, transformations Spark/dbt, serving Dremio/BI.",
    ], "Conception", "Les exigences sont établies. La conception montre comment chaque besoin devient un choix d'architecture."))

    s = base_slide("Conception — Architecture globale", "Sept couches pour passer de la source au pilotage", "Conception")
    s.add_image("rapport/images/screenshots_pipeline/architecture_globale.png", 0.65, 1.35, 7.1, 3.75)
    s.add_text(8.05, 1.35, 4.65, 3.75, [
        p_xml("Lecture de l'architecture", 20, BURGUNDY, True),
        p_xml("Sources → ingestion → stockage → calcul → virtualisation → présentation → observabilité.", 16, INK, bullet=True),
        p_xml("Les composants sont opérés dans Kubernetes pour garder la même logique de déploiement.", 16, INK, bullet=True),
        p_xml("La BI et l'IA consomment la couche Gold, pas les sources brutes.", 16, INK, bullet=True),
    ], fill=WHITE, line=LINE, radius="roundRect")
    s.add_text(0.9, 5.55, 11.5, 0.75, [p_xml("Conviction : séparer stockage, calcul et exposition permet d'évoluer par couches sans reconstruire toute la plateforme.", 17, BURGUNDY, True, align="ctr")], fill=LIGHT, line=LINE, radius="roundRect")
    slides.append(s)

    s = base_slide("Conception — Infrastructure cloud", "EKS comme socle opérable, pas comme dépendance propriétaire", "Conception")
    s.add_image("rapport/images/architecture_infra.png", 0.55, 1.4, 7.45, 2.25)
    s.add_text(8.25, 1.25, 4.35, 4.6, [
        p_xml("Choix clés", 20, BURGUNDY, True),
        p_xml("VPC multi-AZ, sous-réseaux publics/privés, KMS et IAM modulaires via Terraform.", 15, INK, bullet=True),
        p_xml("Deux node groups : stateful-ng toujours actif, compute-ng élastique.", 15, INK, bullet=True),
        p_xml("StorageClass gp3 chiffrée pour les volumes persistants.", 15, INK, bullet=True),
        p_xml("Namespaces platform-* avec quotas et NetworkPolicies.", 15, INK, bullet=True),
    ], fill=WHITE, line=LINE, radius="roundRect")
    s.add_text(0.75, 4.25, 7.1, 1.25, [
        p_xml("Pourquoi MinIO sur EBS ?", 19, RED, True),
        p_xml("Dans EKS, MinIO a besoin d'un stockage persistant et prévisible. L'EBS gp3 évite de dépendre directement de S3 pour la couche Lakehouse, améliore le contrôle opérationnel et garde une interface S3-compatible portable.", 15, INK),
    ], fill=PALE_GOLD, line=YELLOW, radius="roundRect")
    slides.append(s)

    s = base_slide("Conception — Exposition sécurisée", "Cloudflare Operator + TunnelBinding + Zero Trust", "Conception")
    s.add_text(0.75, 1.3, 5.6, 4.75, [
        p_xml("Pourquoi ce choix ?", 20, BURGUNDY, True),
        p_xml("Pas de LoadBalancer public pour Airflow, Dremio, Grafana ou NiFi.", 16, INK, bullet=True),
        p_xml("Tunnel Cloudflare sortant : exposition DNS contrôlée et surface d'attaque réduite.", 16, INK, bullet=True),
        p_xml("TunnelBinding : associer un DNS à un service Kubernetes de manière déclarative.", 16, INK, bullet=True),
        p_xml("Zero Trust : authentification et politiques d'accès par application.", 16, INK, bullet=True),
    ], fill=WHITE, line=LINE, radius="roundRect")
    s.add_image("rapport/images/screenshots_infra/cloudflare_tunnel_connector.png", 6.8, 1.35, 5.75, 3.95)
    s.add_text(6.9, 5.55, 5.55, 0.65, [p_xml("Argument business : sécurité forte, coût faible, accès maîtrisé pour les démonstrations et l'exploitation.", 15, BURGUNDY, True, align="ctr")], fill=LIGHT, line=LINE, radius="roundRect")
    slides.append(s)

    s = base_slide("Conception — Optimisation des coûts", "Planifier le compute selon les heures utiles", "Conception")
    s.add_text(0.85, 1.35, 5.3, 4.8, [
        p_xml("Scheduling proposé", 22, BURGUNDY, True),
        p_xml("08:00 : démarrage des nœuds compute pour les traitements et interfaces.", 17, INK, bullet=True),
        p_xml("18:00 : scale-down / arrêt du compute-ng pour réduire les coûts hors horaires.", 17, INK, bullet=True),
        p_xml("Lambda + EventBridge pilotent les tailles min/desired/max du node group.", 17, INK, bullet=True),
    ], fill=WHITE, line=LINE, radius="roundRect")
    for i, (hour, label, color) in enumerate([("08:00", "Scale up", GREEN), ("Journée", "Traitements", GOLD), ("18:00", "Scale down", RED)]):
        s.add_text(6.75 + i * 1.85, 2.35, 1.45, 1.45, [p_xml(hour, 21, WHITE, True, align="ctr"), p_xml(label, 11, WHITE, True, align="ctr")], fill=color, radius="ellipse", margin=20_000)
        if i < 2:
            s.add_shape(8.18 + i * 1.85, 2.98, 0.35, 0.07, BURGUNDY)
    s.add_text(6.6, 4.45, 5.55, 1.0, [p_xml("Pitch jury", 17, BURGUNDY, True), p_xml("Je n'optimise pas seulement la technique : je transforme une plateforme coûteuse 24/7 en capacité activée quand elle crée de la valeur.", 16, INK)], fill=PALE_GOLD, line=YELLOW, radius="roundRect")
    slides.append(s)

    s = base_slide("Conception — Pipeline data / DataOps", "Un Lakehouse médaillon gouvernable et rejouable", "Conception")
    s.add_image("rapport/images/pipeline_data.png", 0.65, 1.35, 7.8, 1.95)
    s.add_text(8.75, 1.25, 3.75, 4.85, [
        p_xml("Rôles des couches", 20, BURGUNDY, True),
        p_xml("Bronze : vérité brute et traçable.", 16, INK, bullet=True),
        p_xml("Silver : nettoyage, typage, déduplication.", 16, INK, bullet=True),
        p_xml("Gold : indicateurs et vues métier.", 16, INK, bullet=True),
        p_xml("Iceberg apporte tables ACID, schéma et évolution.", 16, INK, bullet=True),
    ], fill=WHITE, line=LINE, radius="roundRect")
    s.add_text(0.8, 4.0, 7.5, 1.55, [p_xml("DataOps", 20, RED, True), p_xml("Airflow orchestre, Spark exécute, dbt structure les transformations, Dremio expose la donnée sans la dupliquer.", 17, INK)], fill=PALE_GOLD, line=YELLOW, radius="roundRect")
    slides.append(s)

    slides.append(section_slide("Réalisation", "Axe 04 · Preuves et livrables", [
        "La plateforme est matérialisée par Terraform, Helm, manifests Kubernetes, DAGs, jobs Spark/dbt et scripts d'exploitation.",
        "Les phases principales sont livrées : socle cloud, stockage, ingestion, compute, serving, exposition, CI/CD, optimisation coûts.",
    ], "Réalisation", "Après l'architecture cible, place aux éléments déployés et aux preuves observables."))

    s = base_slide("Réalisation — Infrastructure cloud", "Socle AWS/EKS déployé et automatisé", "Réalisation")
    s.add_image("rapport/images/screenshots_infra/aws_eks_cluster_overview.png", 0.65, 1.25, 5.75, 2.55)
    s.add_image("rapport/images/screenshots_infra/aws_eks_persistent_volumes.png", 6.8, 1.25, 5.75, 2.55)
    s.add_text(0.85, 4.25, 11.45, 1.25, [
        p_xml("Livrables", 19, BURGUNDY, True),
        p_xml("Modules Terraform VPC/KMS/IAM/EKS/ECR/Lambda, backend R2, namespaces, quotas, NetworkPolicies, StorageClass gp3 chiffrée et scripts bootstrap/teardown.", 16, INK),
    ], fill=WHITE, line=LINE, radius="roundRect")
    slides.append(s)

    s = base_slide("Réalisation — Stockage et métastore", "MinIO, PostgreSQL CNPG, Hive Metastore et zones Lakehouse", "Réalisation")
    s.add_image("rapport/images/screenshots_pipeline/MinIO_object_browser.png", 0.65, 1.25, 5.65, 3.15)
    s.add_image("rapport/images/screenshots_infra/postgres_hive_metastore.png", 6.75, 1.25, 5.75, 3.15)
    s.add_text(0.85, 4.75, 11.35, 0.95, [p_xml("Preuve fonctionnelle : les zones Bronze, Silver et Gold existent dans le stockage objet, avec un catalogue technique pour requêter les tables Iceberg.", 17, BURGUNDY, True, align="ctr")], fill=LIGHT, line=LINE, radius="roundRect")
    slides.append(s)

    s = base_slide("Réalisation — Pipeline data / DataOps", "Ingestion, orchestration et transformations", "Réalisation")
    s.add_image("rapport/images/screenshots_pipeline/airflow_UI.png", 0.65, 1.25, 3.85, 2.25)
    s.add_image("rapport/images/screenshots_pipeline/medaillon_pipeline_graph.png", 4.75, 1.25, 3.85, 2.25)
    s.add_image("rapport/images/screenshots_pipeline/spark_master_UI.png", 8.85, 1.25, 3.5, 2.25)
    s.add_text(0.85, 4.0, 11.35, 1.45, [
        p_xml("Ce qui est démontré", 19, BURGUNDY, True),
        p_xml("DAGs Airflow versionnés, SparkApplications, projet dbt, ingestion fichiers, flux NiFi, Kafka/Strimzi et transformation Bronze → Silver → Gold.", 17, INK),
    ], fill=WHITE, line=LINE, radius="roundRect")
    slides.append(s)

    s = base_slide("Réalisation — Tables et indicateurs", "De la donnée brute à la vision métier", "Réalisation")
    s.add_image("rapport/images/screenshots_pipeline/table_bronze_inf_client.png", 0.65, 1.25, 3.6, 2.2)
    s.add_image("rapport/images/screenshots_pipeline/table_silver_info_client.png", 4.85, 1.25, 3.6, 2.2)
    s.add_image("rapport/images/screenshots_pipeline/table_gold_scoring360.png", 8.95, 1.25, 3.6, 2.2)
    s.add_image("rapport/images/screenshots_pipeline/KPIs_Vue_contrats360.png", 1.35, 4.0, 10.55, 1.85)
    slides.append(s)

    s = base_slide("Réalisation — Serving et BI", "Dremio expose les tables Gold aux analystes", "Réalisation")
    s.add_text(0.75, 1.35, 4.55, 4.65, [
        p_xml("Pourquoi Dremio ?", 20, BURGUNDY, True),
        p_xml("Requête SQL sur Iceberg sans déplacer la donnée.", 16, INK, bullet=True),
        p_xml("Connexion BI via ODBC ou Arrow Flight.", 16, INK, bullet=True),
        p_xml("Découplage entre stockage Lakehouse et consommation métier.", 16, INK, bullet=True),
        p_xml("Plus de flexibilité qu'un data warehouse fermé pour un MVP cloud-ready.", 16, INK, bullet=True),
    ], fill=WHITE, line=LINE, radius="roundRect")
    s.add_image("rapport/images/dashboard1.png", 5.7, 1.3, 6.65, 4.2)
    slides.append(s)

    slides.append(section_slide("Valeur créée", "Axe 05 · Lecture synthétique", [
        "Mesurer l'apport du socle au-delà de la démonstration technique.",
        "Relier les décisions d'architecture à la confiance, au délai et à la maîtrise.",
        "Distinguer la valeur immédiate de la trajectoire d'industrialisation.",
    ], "Valeur", "Les composants sont en place. Il reste à expliciter ce que cette architecture change concrètement pour EQDOM."))

    s = base_slide("Décisions défendables devant le jury", "Le business case derrière les choix techniques", "Synthèse")
    decisions = [
        ("EKS + Kubernetes", "standard d'exploitation, opérateurs, scalabilité et trajectoire multi-cloud"),
        ("MinIO sur EBS", "stockage persistant, S3-compatible, plus contrôlable dans EKS et moins dépendant de S3"),
        ("Cloudflare Zero Trust", "exposition sécurisée, DNS déclaratif, pas de LoadBalancer public, coût faible"),
        ("Lambda scheduling", "capacité active de 08:00 à 18:00, réduction des coûts hors horaires"),
        ("Lakehouse Iceberg", "traçabilité, schéma, ACID et base solide pour BI/IA"),
        ("Airflow + Spark + dbt", "orchestration, calcul distribué et transformations versionnées"),
    ]
    for i, (d, v) in enumerate(decisions):
        x = 0.7 + (i % 2) * 6.1
        y = 1.25 + (i // 2) * 1.45
        s.add_text(x, y, 5.55, 1.05, [p_xml(d, 17, BURGUNDY, True), p_xml(v, 13, INK)], fill=WHITE, line=LINE, radius="roundRect")
    slides.append(s)

    s = base_slide("Valeur créée", "Ce que la plateforme apporte à EQDOM", "Valeur")
    add_three_cards(s, [
        ("Time-to-data", "Accélérer la mise à disposition des données fiables pour les tableaux de bord et les cas IA.", BURGUNDY),
        ("Confiance", "Traçabilité Bronze/Silver/Gold, transformations versionnées, supervision et capacité de rejeu.", RED),
        ("Maîtrise", "Coûts pilotés, exposition sécurisée, infrastructure reproductible et cloud agnostic.", GOLD),
    ])
    s.add_text(0.95, 4.3, 11.25, 1.3, [p_xml("Phrase de soutenance", 19, BURGUNDY, True), p_xml("J'ai conçu la plateforme comme un actif d'entreprise : elle ne répond pas seulement au besoin du jour, elle prépare EQDOM à industrialiser ses usages BI, analytics et IA.", 18, INK, True)], fill=PALE_GOLD, line=YELLOW, radius="roundRect")
    slides.append(s)

    slides.append(section_slide("Limites et perspectives", "Axe 06 · Trajectoire", [
        "Assumer les limites du MVP avec transparence.",
        "Prioriser les renforcements nécessaires pour la production.",
        "Projeter les cas d'usage métier rendus possibles par le socle.",
    ], "Perspectives", "La conclusion ne fige pas la plateforme : elle présente les prochains jalons d'une industrialisation maîtrisée."))

    s = base_slide("Limites et perspectives", "Une trajectoire d'industrialisation claire", "Perspectives")
    s.add_text(0.85, 1.35, 5.65, 4.5, [
        p_xml("Limites assumées", 20, BURGUNDY, True),
        p_xml("Dashboards Grafana et règles d'alerting à finaliser.", 16, INK, bullet=True),
        p_xml("GitOps ArgoCD présent mais activation complète à industrialiser.", 16, INK, bullet=True),
        p_xml("Durcissement PROD : sauvegardes, HA, tests de charge, politiques d'accès détaillées.", 16, INK, bullet=True),
    ], fill=WHITE, line=LINE, radius="roundRect")
    s.add_text(6.85, 1.35, 5.65, 4.5, [
        p_xml("Perspectives", 20, RED, True),
        p_xml("Promotions DEV → UAT → PROD via GitOps.", 16, INK, bullet=True),
        p_xml("Data quality automatisée et catalogage métier.", 16, INK, bullet=True),
        p_xml("Cas d'usage fraude, proactivité commerciale et recouvrement optimisé.", 16, INK, bullet=True),
    ], fill=PALE_GOLD, line=YELLOW, radius="roundRect")
    slides.append(s)

    slides.append(title_slide())
    return slides


def slide_xml(slide: Slide, num: int, rels: list[tuple[str, str]]) -> str:
    elems = []
    img_idx = 0
    for el in slide.elems:
        if isinstance(el, tuple) and el[0] == "IMAGE":
            _, n, x, y, cx, cy, idx = el
            rid = f"rId{n}"
            elems.append(image_xml(idx, rid, x, y, cx, cy))
        else:
            elems.append(el)
    if num > 1:
        elems.append(tx_box(999, 9.42, 6.95, 3.0, 0.28, [p_xml(str(num), 10, MUTED, False, align="ctr")], margin=2_000))
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
       xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
      {''.join(elems)}
    </p:spTree>
  </p:cSld>
  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
  <p:transition spd="slow"><p:fade/></p:transition>
</p:sld>"""


def write_package(slides: list[Slide]) -> None:
    tmp = Path(tempfile.mkdtemp(prefix="pptx-build-"))
    try:
        (tmp / "_rels").mkdir()
        (tmp / "docProps").mkdir()
        (tmp / "ppt" / "_rels").mkdir(parents=True)
        (tmp / "ppt" / "slides" / "_rels").mkdir(parents=True)
        (tmp / "ppt" / "media").mkdir(parents=True)

        overrides = [
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
            '<Default Extension="xml" ContentType="application/xml"/>',
            '<Default Extension="png" ContentType="image/png"/>',
            '<Default Extension="jpg" ContentType="image/jpeg"/>',
            '<Default Extension="jpeg" ContentType="image/jpeg"/>',
            '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>',
            '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>',
            '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>',
        ]
        for i in range(1, len(slides) + 1):
            overrides.append(f'<Override PartName="/ppt/slides/slide{i}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>')
        (tmp / "[Content_Types].xml").write_text(
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            + "".join(overrides)
            + "</Types>",
            encoding="utf-8",
        )
        (tmp / "_rels" / ".rels").write_text(
            """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>""",
            encoding="utf-8",
        )
        (tmp / "docProps" / "core.xml").write_text(
            """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>Soutenance Cloud Data Platform EQDOM</dc:title>
  <dc:creator>Mohammed Dahiry</dc:creator>
  <cp:lastModifiedBy>Codex</cp:lastModifiedBy>
</cp:coreProperties>""",
            encoding="utf-8",
        )
        (tmp / "docProps" / "app.xml").write_text(
            f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Codex OpenXML Generator</Application><PresentationFormat>On-screen Show (16:9)</PresentationFormat><Slides>{len(slides)}</Slides>
</Properties>""",
            encoding="utf-8",
        )

        slide_ids = []
        pres_rels = []
        media_count = 0
        for i, sl in enumerate(slides, 1):
            rels = []
            for j, src in enumerate(sl.images, 1):
                media_count += 1
                ext = src.suffix.lower().lstrip(".")
                media_name = f"image{media_count}.{ext}"
                shutil.copyfile(src, tmp / "ppt" / "media" / media_name)
                rels.append((f"rId{j}", f"../media/{media_name}"))
            (tmp / "ppt" / "slides" / f"slide{i}.xml").write_text(slide_xml(sl, i, rels), encoding="utf-8")
            rel_xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">']
            for rid, target in rels:
                rel_xml.append(f'<Relationship Id="{rid}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="{target}"/>')
            rel_xml.append("</Relationships>")
            (tmp / "ppt" / "slides" / "_rels" / f"slide{i}.xml.rels").write_text("".join(rel_xml), encoding="utf-8")
            slide_ids.append(f'<p:sldId id="{255+i}" r:id="rId{i}"/>')
            pres_rels.append(f'<Relationship Id="rId{i}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide{i}.xml"/>')

        (tmp / "ppt" / "presentation.xml").write_text(
            f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldIdLst>{''.join(slide_ids)}</p:sldIdLst>
  <p:sldSz cx="{W}" cy="{H}" type="wide"/>
  <p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>""",
            encoding="utf-8",
        )
        (tmp / "ppt" / "_rels" / "presentation.xml.rels").write_text(
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            + "".join(pres_rels)
            + "</Relationships>",
            encoding="utf-8",
        )

        OUT.parent.mkdir(exist_ok=True)
        if OUT.exists():
            OUT.unlink()
        with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
            for path in tmp.rglob("*"):
                if path.is_file():
                    z.write(path, path.relative_to(tmp).as_posix())
    finally:
        shutil.rmtree(tmp)


if __name__ == "__main__":
    slides = deck()
    write_package(slides)
    print(f"Wrote {OUT} ({len(slides)} slides)")
