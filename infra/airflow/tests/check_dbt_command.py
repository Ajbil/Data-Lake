"""Check the production shell's stage/exit contract with controlled dbt exits.

Run with Python and Bash, passing the production DAG file as the only argument.
This does not import Airflow, connect to services, or execute real dbt.
"""

import ast
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile


def check(dag_file: str) -> None:
    tree = ast.parse(Path(dag_file).read_text(encoding="utf-8"))
    command = next(
        ast.literal_eval(node.value)
        for node in tree.body
        if isinstance(node, ast.Assign)
        and any(isinstance(t, ast.Name) and t.id == "DBT_COMMAND" for t in node.targets)
    )
    with tempfile.TemporaryDirectory() as directory:
        # Only relocate the working directory; preserve production stage logic.
        command = command.replace("cd /opt/airflow/dbt", f"cd {shlex.quote(directory)}")
        for run_code, test_code in ((0, 0), (17, 0), (0, 1), (0, 99)):
            stub = (
                'dbt() { echo "[stub] dbt $1"; '
                f'if [ "$1" = run ]; then return {run_code}; '
                f'else return {test_code}; fi; }}\n'
            )
            result = subprocess.run(
                ["bash", "-c", stub + command], capture_output=True, text=True, check=False
            )
            output = result.stdout + result.stderr
            expected_code = run_code or test_code
            assert result.returncode == expected_code, output
            assert ("[stub] dbt test" in output) == (run_code == 0), output
            if expected_code:
                stage = "dbt_run" if run_code else "dbt_test"
                assert f"FAILED stage={stage} exit_code={expected_code}" in output, output
                assert "SUCCESS all stages completed" not in output, output
                assert f"SUCCESS stage={stage}" not in output, output
            else:
                assert "SUCCESS stage=dbt_run" in output, output
                assert "SUCCESS stage=dbt_test" in output, output
                assert "SUCCESS all stages completed" in output, output
            print(f"PASS run_exit={run_code} test_exit={test_code} process_exit={result.returncode}")


if __name__ == "__main__":
    check(sys.argv[1])
