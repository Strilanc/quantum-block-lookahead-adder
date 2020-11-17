from typing import Union, List, Optional

import dataclasses
import math

import cirq


@dataclasses.dataclass
class SimpleFormula:
    O_1: bool = False
    constant: int = 0
    lg_n: Union[int, float] = 0
    sqrt_n: Union[int, float] = 0
    n: Union[int, float] = 0
    n2: Union[int, float] = 0

    def value(self, n: int):
        return (
            self.n2 * n * n
            + self.n * n
            + self.sqrt_n * math.sqrt(n)
            + self.lg_n * math.log2(n)
            + self.constant
            + (10 if self.O_1 else 0)
        )

    def latex(self) -> str:
        terms = []
        def factor(x):
            if x == 1:
                return ''
            if x == -1:
                return '-'
            return str(x)

        if self.n2:
            terms.append(factor(self.n2) + "n^2")
        if self.n:
            terms.append(factor(self.n) + "n")
        if self.sqrt_n:
            terms.append(factor(self.sqrt_n) + r"\sqrt n")
        if self.lg_n:
            terms.append(factor(self.lg_n) + r"\lg n")
        if self.O_1:
            terms.append("O(1)")
        if self.constant:
            terms.append(str(self.constant))
        if not terms:
            return "0"
        result = "$" + " + ".join(terms) + "$"
        result = result.replace('+ -', '- ')
        return result


@dataclasses.dataclass
class Adder:
    author: str
    year: int
    citation: Optional[str]
    type: str
    in_place: bool
    toffolis: SimpleFormula
    reaction_depth: SimpleFormula
    workspace: SimpleFormula
    utilization: float = 1.0

    def vol(self,
            *,
            n: int,
            factory_count: int,
            factory_period: int = 165,
            factory_area: int = 12 * 6,
            reaction_time: int = 10):
        tof = self.toffolis.value(n)
        dep = self.reaction_depth.value(n)
        space = self.workspace.value(n)
        if self.in_place:
            space += 2*n
        else:
            space += 3*n
        time = max(factory_period * (tof / factory_count) / self.utilization, reaction_time * dep)
        result = factory_area * factory_period * tof + space * time
        result /= 1000 * 1000
        result = str(int(result))

        # 2 sig figs
        if len(result) > 2:
            result = result[:2] + '0' * (len(result) - 2)

        return result


def make_table(adders: List[Adder]) -> str:
    adders = sorted(adders, key=lambda adder: (adder.reaction_depth.value(1000000) + adder.year*20, adder.year, adder.author))
    in_place_adders = [adder for adder in adders if adder.in_place]
    out_of_place_adders = [adder for adder in adders if not adder.in_place]
    in_place_row = 2
    out_of_place_row = 4 + len(in_place_adders)
    diagram = cirq.TextDiagramDrawer()
    diagram.write(0, in_place_row - 1, r"\hline")
    diagram.write(0, out_of_place_row - 1, r"\hline")
    params = [(100, 10), (1000, 100), (10000, 1000)]
    vol_col = 7
    last_col = vol_col + len(params)

    diagram.write(0, 0, "Paper")
    diagram.write(1, 0, "&Place")
    diagram.write(2, 0, "&Type")
    diagram.write(3, 0, "&Toffolis")
    diagram.write(4, 0, "&Reaction Depth")
    diagram.write(5, 0, "&Workspace")
    diagram.write(6, 0, "&u")
    diagram.write(last_col, 0, '\\\\')
    for c, (n, f) in enumerate(params):
        diagram.write(vol_col + c, 0, f"&V(n={n},f={f})")
    for (row, adders) in [(in_place_row, in_place_adders), (out_of_place_row, out_of_place_adders)]:
        for r, adder in enumerate(adders):
            diagram.write(0, row + r, f"{adder.author} ({adder.year})" + (r' \cite{' + adder.citation + '}' if adder.citation is not None else ''))
            diagram.write(1, row + r, '&' + ('in' if adder.in_place else 'out'))
            diagram.write(2, row + r, '&' + adder.type)
            diagram.write(3, row + r, '&' + adder.toffolis.latex())
            diagram.write(4, row + r, '&' + adder.reaction_depth.latex())
            diagram.write(5, row + r, '&' + adder.workspace.latex())
            diagram.write(6, row + r, f'&{adder.utilization:.2}' if adder.utilization != 1 else '&1')
            for c, (n, f) in enumerate(params):
                diagram.write(vol_col + c, row + r, '&' + adder.vol(n=n, factory_count=f))
            diagram.write(last_col, row + r, '\\\\')
    contents = diagram.render(horizontal_spacing=1, vertical_spacing=0)
    return r"\begin{tabular}{r|c|c|l|l|l|c" + '|c' * len(params) + "}\n" + contents + "\n\end{tabular}"

if __name__ == '__main__':
    print(make_table([
        Adder(
            author="Cuccaro",
            year=2004,
            citation="cuccaro2004adder",
            type="Ripple Carry",
            in_place=True,
            toffolis=SimpleFormula(n=2, constant=-1),
            reaction_depth=SimpleFormula(n=2, constant=-1),
            workspace=SimpleFormula(constant=1),
        ),
        Adder(
            author="Gidney",
            year=2017,
            citation="gidney2018halving",
            type="Ripple Carry",
            in_place=False,
            toffolis=SimpleFormula(n=1, constant=-1),
            reaction_depth=SimpleFormula(n=1, constant=-1),
            workspace=SimpleFormula(constant=1),
        ),
        Adder(
            author="Gidney",
            year=2017,
            citation="gidney2018halving",
            type="Ripple Carry",
            in_place=True,
            utilization=0.5,
            toffolis=SimpleFormula(n=1, constant=-1),
            reaction_depth=SimpleFormula(n=2, constant=-1),
            workspace=SimpleFormula(n=1),
        ),
        Adder(
            author="Gossett",
            year=1998,
            citation="gossett1998carrysave",
            type="Pipelined (n summands)",
            in_place=False,
            toffolis=SimpleFormula(n=4),
            reaction_depth=SimpleFormula(constant=2),
            workspace=SimpleFormula(n2=1, n=-2),
        ),
        Adder(
            author="Draper et al.",
            year=2004,
            citation="draper2004lookaheadadder",
            type="Carry Lookahead",
            in_place=False,
            workspace=SimpleFormula(n=1, lg_n=-1),
            reaction_depth=SimpleFormula(lg_n=2, constant=6 - 3),
            toffolis=SimpleFormula(n=5, lg_n=-3, constant=-4),
        ),
        Adder(
            author="Draper et al.",
            year=2004,
            citation="draper2004lookaheadadder",
            type="Carry Lookahead",
            in_place=True,
            workspace=SimpleFormula(n=2, lg_n=-1, constant=-1),
            reaction_depth=SimpleFormula(lg_n=4, constant=14 - 7),
            toffolis=SimpleFormula(n=10, lg_n=-6, constant=-13),
        ),
        Adder(
            author="(this paper)",
            citation=None,
            year=2020,
            type="Two Blocks",
            in_place=False,
            toffolis=SimpleFormula(n=2),
            reaction_depth=SimpleFormula(n=1, O_1=True),
            workspace=SimpleFormula(n=1),
            utilization=4/6,
        ),
        Adder(
            author="(this paper)",
            citation=None,
            year=2020,
            type="Two Blocks",
            in_place=True,
            toffolis=SimpleFormula(n=3),
            reaction_depth=SimpleFormula(n=1.5, O_1=True),
            workspace=SimpleFormula(n=1),
            utilization=3/4,
        ),
        Adder(
            author="(this paper)",
            citation=None,
            year=2020,
            type="Carry Lookahead",
            in_place=True,
            toffolis=SimpleFormula(n=7),
            reaction_depth=SimpleFormula(lg_n=4, O_1=True),
            workspace=SimpleFormula(n=4, O_1=True),
        ),
        Adder(
            author="(this paper)",
            citation=None,
            year=2020,
            type="Carry Lookahead",
            in_place=False,
            toffolis=SimpleFormula(n=4),
            reaction_depth=SimpleFormula(lg_n=2, O_1=True),
            workspace=SimpleFormula(n=3, O_1=True),
        ),
        Adder(
            author="(this paper)",
            citation=None,
            year=2020,
            type="Sqrt Blocks",
            in_place=True,
            toffolis=SimpleFormula(n=5, sqrt_n=6, O_1=True),
            reaction_depth=SimpleFormula(sqrt_n=6, lg_n=4, O_1=True),
            workspace=SimpleFormula(n=2, sqrt_n=5, O_1=True),
        ),
        Adder(
            author="(this paper)",
            year=2020,
            citation=None,
            type="Sqrt Blocks",
            in_place=False,
            toffolis=SimpleFormula(n=3, sqrt_n=3, O_1=True),
            reaction_depth=SimpleFormula(sqrt_n=3, lg_n=2, O_1=True),
            workspace=SimpleFormula(n=2, sqrt_n=5, O_1=True),
        ),
    ]))
